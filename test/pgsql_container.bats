load common

# Back up a read-only postgres:18-alpine container through the podman
# transport, the way a Mattermost database is typically deployed.

BN_PG_IMAGE="docker.io/library/postgres:18-alpine"
BN_PG_CONTAINER="bntest-mattermost-db"
BN_PG_NOBASH="bntest-nobash-db"

pg_start() {
    local name="$1"
    shift
    podman run -d --name "$name" "$@" \
        -e POSTGRES_USER=mmuser -e POSTGRES_PASSWORD=bntest-secret -e POSTGRES_DB=mattermost \
        "$BN_PG_IMAGE"
    # the init server only listens on the socket; wait for the final one
    for _ in $(seq 120); do
        podman exec "$name" pg_isready -q -h 127.0.0.1 -U mmuser && break
        sleep 1
    done
    podman exec "$name" pg_isready -q -h 127.0.0.1 -U mmuser
    podman exec "$name" psql -v ON_ERROR_STOP=1 -U mmuser -d mattermost \
        -c "CREATE TABLE posts (id int PRIMARY KEY, message text)" \
        -c "INSERT INTO posts SELECT i, 'message ' || i FROM generate_series(1, 42) i"
}

begin_pgsql_container() {
    command -v podman >/dev/null || install_pkgs podman
    podman pull -q "$BN_PG_IMAGE"
    pg_start "$BN_PG_CONTAINER" --read-only --tmpfs /tmp --tmpfs /var/run/postgresql \
        -v bntest-mattermost-data:/var/lib/postgresql
}

finish_pgsql_container() {
    podman rm -f -v -t 0 "$BN_PG_CONTAINER" "$BN_PG_NOBASH" || true
    podman volume rm -f bntest-mattermost-data || true
}

setup_pgsql_container() {
    cat << EOF > "${BATS_TMPDIR}/backup.d/test.pgsql"
databases = mattermost
backupdir = /tmp/backups/mattermost
compress = no
format = plain
dbusername = mmuser

[transport]
transport = podman
container = ${BN_PG_CONTAINER}
hostbackupdir = ${BN_BACKUPDIR}/mattermost
EOF
    chmod 0640 "${BATS_TMPDIR}/backup.d/test.pgsql"
}

teardown_pgsql_container() {
    cleanup_backups local
}

pgconfig() {
    setconfig backup.d/test.pgsql "$@"
}

@test "container has a read-only rootfs and no mmuser system user" {
    run podman exec "$BN_PG_CONTAINER" touch /var/backups-probe
    [ "$status" -ne 0 ]
    run podman exec "$BN_PG_CONTAINER" getent passwd mmuser
    [ "$status" -ne 0 ]
    podman exec "$BN_PG_CONTAINER" getent passwd postgres
    podman exec "$BN_PG_CONTAINER" sh -c 'command -v tar && command -v su'
}

@test "dumps mattermost as mmuser into the host backup directory" {
    runaction test.pgsql
    greplog "Info: Successfully finished dump of pgsql database mattermost"
    not_greplog "Error:"
    not_greplog "Warning:"
    local dump="${BN_BACKUPDIR}/mattermost/mattermost.sql"
    [ -s "$dump" ]
    grep -q '^COPY public.posts' "$dump"
    [ -z "$(ls -A "${BN_BACKUPDIR}/mattermost" | grep -v '^mattermost.sql$')" ]
    run podman exec "$BN_PG_CONTAINER" ls -A /tmp/backups/mattermost
    [ "$output" = mattermost.sql ]

    # restore into another database
    podman exec "$BN_PG_CONTAINER" createdb -U mmuser bntest_restore
    podman exec -i "$BN_PG_CONTAINER" psql -q -v ON_ERROR_STOP=1 -U mmuser -d bntest_restore < "$dump"
    run podman exec "$BN_PG_CONTAINER" psql -At -U mmuser -d bntest_restore \
        -c "SELECT count(*), max(message) FROM posts WHERE message LIKE 'message %'"
    podman exec "$BN_PG_CONTAINER" dropdb -U mmuser bntest_restore
    [ "$output" = "42|message 9" ]
}

@test "compressed dump works with busybox gzip" {
    pgconfig compress yes
    runaction test.pgsql
    greplog "Warning: .*gzip does not support the options '--rsyncable'"
    greplog "Info: Successfully finished dump of pgsql database mattermost"
    not_greplog "Error:"
    gzip -t "${BN_BACKUPDIR}/mattermost/mattermost.sql.gz"
    zgrep -q '^COPY public.posts' "${BN_BACKUPDIR}/mattermost/mattermost.sql.gz"
}

@test "dumps a container without bash" {
    pg_start "$BN_PG_NOBASH" --tmpfs /var/run/postgresql
    podman exec "$BN_PG_NOBASH" rm -f /bin/bash /usr/bin/bash
    run podman exec "$BN_PG_NOBASH" sh -c 'command -v bash || exit 1'
    [ "$status" -eq 1 ]
    pgconfig transport container "$BN_PG_NOBASH"
    pgconfig transport hostbackupdir "${BN_BACKUPDIR}/nobash"
    for compress in no yes; do
        pgconfig compress "$compress"
        runaction test.pgsql
        not_greplog "Error:"
    done
    grep -q '^COPY public.posts' "${BN_BACKUPDIR}/nobash/mattermost.sql"
    zgrep -q '^COPY public.posts' "${BN_BACKUPDIR}/nobash/mattermost.sql.gz"
}

@test "missing system user is fatal" {
    pgconfig dbusername ""
    echo "PGSQLUSER=mmuser" >> "${BATS_TMPDIR}/backupninja.conf"
    runaction test.pgsql
    greplog "Fatal: No system user called mmuser"
}

@test "unknown database role keeps the previous host backup" {
    mkdir -p "${BN_BACKUPDIR}/mattermost"
    echo previous > "${BN_BACKUPDIR}/mattermost/mattermost.sql"
    pgconfig dbusername bntest_nosuchrole
    runaction test.pgsql
    greplog "Error: Failed to dump pgsql database mattermost"
    greplog "Error: Not fetching backups"
    [ "$(cat "${BN_BACKUPDIR}/mattermost/mattermost.sql")" = previous ]
}

@test "missing database keeps the previous host backup" {
    runaction test.pgsql
    mkdir -p "${BN_BACKUPDIR}/mattermost"
    echo previous > "${BN_BACKUPDIR}/mattermost/bntest_missing.sql"
    pgconfig databases bntest_missing
    runaction test.pgsql
    greplog "Error: Failed to dump pgsql database bntest_missing"
    [ "$(cat "${BN_BACKUPDIR}/mattermost/bntest_missing.sql")" = previous ]
    run podman exec "$BN_PG_CONTAINER" ls -A /tmp/backups/mattermost
    [[ "$output" != *partial* ]]
}

@test "copy failure is fatal and keeps the previous host backup" {
    mkdir -p "${BN_BACKUPDIR}/mattermost"
    echo previous > "${BN_BACKUPDIR}/mattermost/mattermost.sql"
    # the container side succeeds, but the host side cannot be written
    mkdir -p "${BN_BACKUPDIR}/readonly"
    mount -t tmpfs -o ro tmpfs "${BN_BACKUPDIR}/readonly"
    pgconfig transport hostbackupdir "${BN_BACKUPDIR}/readonly/mattermost"
    runaction test.pgsql
    umount "${BN_BACKUPDIR}/readonly"
    greplog "Fatal: Cannot create host backup directory"

    # the transfer from the container fails midway
    cat > "${BATS_TEST_TMPDIR}/podman" <<'EOF'
#!/bin/sh
case "$*" in
    *" tar -cf "*) podman "$@" | head -c 1000; exit 1 ;;
esac
exec podman "$@"
EOF
    chmod +x "${BATS_TEST_TMPDIR}/podman"
    pgconfig transport hostbackupdir "${BN_BACKUPDIR}/mattermost"
    pgconfig transport podman "${BATS_TEST_TMPDIR}/podman"
    runaction test.pgsql
    greplog "Fatal: Failed to fetch"
    [ "$(cat "${BN_BACKUPDIR}/mattermost/mattermost.sql")" = previous ]
    [ "$(ls -A "${BN_BACKUPDIR}/mattermost")" = mattermost.sql ]
}
