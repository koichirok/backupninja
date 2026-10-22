load common

BN_ALPINE_CONTAINER=bntest-posix-target

begin_container_shell() {
    command -v podman >/dev/null || install_pkgs podman
    podman run -d --name "$BN_ALPINE_CONTAINER" docker.io/library/alpine:3.23 sh -ec '
        apk add --no-cache mariadb mariadb-client
        mkdir -p /run/mysqld
        chown mysql /run/mysqld
        mariadb-install-db --user=mysql --datadir=/var/lib/mysql
        exec mariadbd --user=mysql --datadir=/var/lib/mysql --skip-networking
    '
    ready=0
    for _ in $(seq 180); do
        if podman exec "$BN_ALPINE_CONTAINER" mariadb-admin ping >/dev/null 2>&1; then
            ready=1
            break
        fi
        sleep 1
    done
    if [ "$ready" -ne 1 ]; then
        podman logs "$BN_ALPINE_CONTAINER"
        return 1
    fi
    podman exec "$BN_ALPINE_CONTAINER" mariadb -e "
        CREATE DATABASE app;
        CREATE TABLE app.posts (id int PRIMARY KEY, message text);
        INSERT INTO app.posts VALUES (1, 'hello'), (2, 'POSIX shell');
        CREATE TABLE app.cache (id int PRIMARY KEY);
        INSERT INTO app.cache VALUES (1);
    "
    podman exec -i "$BN_ALPINE_CONTAINER" sh -ec 'cat > /tmp/client.cnf' <<'EOF'
[client]
socket=/run/mysqld/mysqld.sock
EOF
    podman exec -i "$BN_ALPINE_CONTAINER" sh -ec 'cat > /usr/local/bin/gitlab-backup; chmod +x /usr/local/bin/gitlab-backup' <<'EOF'
#!/bin/sh
mkdir -p /tmp/gitlab
if [ "$GITLAB_TEST_FAIL" = yes ]; then
    echo partial > /tmp/gitlab/archive.tar
    exit 1
fi
printf '%s\n' "$@" > /tmp/gitlab/archive.tar
EOF
}

finish_container_shell() {
    podman rm -f -v -t 0 "$BN_ALPINE_CONTAINER"
}

setup_container_shell() {
    cat >> "${BATS_TMPDIR}/backupninja.conf" <<'EOF'
MYSQL = /usr/bin/mariadb
MYSQLADMIN = /usr/bin/mariadb-admin
MYSQLDUMP = /usr/bin/mariadb-dump
GZIP_OPTS = -n
EOF
    cat > "${BATS_TMPDIR}/backup.d/test.mysql" <<EOF
databases = app
backupdir = /tmp/mysql
sqldump = yes
compress = no
configfile = /tmp/client.cnf
[transport]
transport = podman
container = ${BN_ALPINE_CONTAINER}
hostbackupdir = ${BN_BACKUPDIR}/mysql-host
EOF
    cat > "${BATS_TMPDIR}/backup.d/test.gitlab" <<EOF
backupdir = /tmp/gitlab
[transport]
transport = podman
container = ${BN_ALPINE_CONTAINER}
hostbackupdir = ${BN_BACKUPDIR}/gitlab-host
EOF
    chmod 0640 "${BATS_TMPDIR}/backup.d/test.mysql" "${BATS_TMPDIR}/backup.d/test.gitlab"
}

teardown_container_shell() {
    cleanup_backups local
}

@test "Alpine target has BusyBox sh and no Bash" {
    podman exec "$BN_ALPINE_CONTAINER" sh -c 'test "$(readlink /bin/sh)" = /bin/busybox'
    run podman exec "$BN_ALPINE_CONTAINER" sh -c 'command -v bash || exit 1'
    [ "$status" -eq 1 ]
}

@test "MySQL plain dump restores on a Bash-free Alpine target" {
    runaction test.mysql
    [ "$status" -eq 0 ]
    not_greplog 'Error:'
    [ -s "${BN_BACKUPDIR}/mysql-host/sqldump/app.sql" ]
    podman exec "$BN_ALPINE_CONTAINER" mariadb -e 'CREATE DATABASE restored'
    podman exec -i "$BN_ALPINE_CONTAINER" mariadb restored < "${BN_BACKUPDIR}/mysql-host/sqldump/app.sql"
    run podman exec "$BN_ALPINE_CONTAINER" mariadb -NB restored -e 'SELECT COUNT(*) FROM posts'
    [ "$status" -eq 0 ]
    [ "$output" = 2 ]
    podman exec "$BN_ALPINE_CONTAINER" mariadb -e 'DROP DATABASE restored'
}

@test "MySQL compressed all-database dump works with BusyBox gzip" {
    setconfig backup.d/test.mysql databases all
    setconfig backup.d/test.mysql compress yes
    runaction test.mysql
    [ "$status" -eq 0 ]
    not_greplog 'Error:'
    gzip -t "${BN_BACKUPDIR}/mysql-host/sqldump/app.sql.gz"
    zgrep -q 'INSERT INTO.*posts' "${BN_BACKUPDIR}/mysql-host/sqldump/app.sql.gz"
}

@test "MySQL reports unsupported gzip options without losing the dump" {
    setconfig backupninja.conf GZIP_OPTS --rsyncable
    setconfig backup.d/test.mysql compress yes
    runaction test.mysql
    [ "$status" -eq 1 ]
    greplog "Warning: .*gzip does not support the options '--rsyncable'"
    not_greplog 'Error:'
    gzip -t "${BN_BACKUPDIR}/mysql-host/sqldump/app.sql.gz"
}

@test "MySQL nodata retains table structure without rows on Alpine" {
    setconfig backup.d/test.mysql nodata app.cache
    setconfig backup.d/test.mysql compress yes
    runaction test.mysql
    [ "$status" -eq 0 ]
    zgrep -q 'CREATE TABLE.*cache' "${BN_BACKUPDIR}/mysql-host/sqldump/app.sql.gz"
    run zgrep 'INSERT INTO.*cache' "${BN_BACKUPDIR}/mysql-host/sqldump/app.sql.gz"
    [ "$status" -eq 1 ]
}

@test "MySQL compressed producer failure preserves container and host backups" {
    for compress in no yes; do
        setconfig backup.d/test.mysql compress "$compress"
        runaction test.mysql
        [ "$status" -eq 0 ]
        ext=sql
        [ "$compress" != yes ] || ext=sql.gz
        previous=$(sha256sum "${BN_BACKUPDIR}/mysql-host/sqldump/app.$ext")
        container_previous=$(podman exec "$BN_ALPINE_CONTAINER" sha256sum "/tmp/mysql/sqldump/app.$ext")
        setconfig backup.d/test.mysql sqldumpoptions '--no-such-backupninja-option'
        runaction test.mysql
        [ "$status" -ne 0 ]
        greplog 'Error: Failed to dump mysql databases app'
        [ "$(sha256sum "${BN_BACKUPDIR}/mysql-host/sqldump/app.$ext")" = "$previous" ]
        [ "$(podman exec "$BN_ALPINE_CONTAINER" sha256sum "/tmp/mysql/sqldump/app.$ext")" = "$container_previous" ]
        podman exec "$BN_ALPINE_CONTAINER" sh -c 'test -z "$(find /tmp/mysql -name "*.partial")"'
        setconfig backup.d/test.mysql sqldumpoptions '--quick'
    done
}

@test "MySQL schema-only failure is not hidden by the data dump" {
    setconfig backup.d/test.mysql nodata app.missing_table
    setconfig backup.d/test.mysql compress yes
    runaction test.mysql
    [ "$status" -ne 0 ]
    greplog 'Error: Failed to dump mysql databases app'
    [ ! -e "${BN_BACKUPDIR}/mysql-host" ]
}

@test "MySQL hotcopy command paths work without Bash" {
    podman exec -i "$BN_ALPINE_CONTAINER" sh -ec 'cat > /tmp/hotcopy; chmod +x /tmp/hotcopy' <<'EOF'
#!/bin/sh
for destination do :; done
printf hotcopy > "$destination/hotcopy-result"
EOF
    echo 'MYSQLHOTCOPY = /tmp/hotcopy' >> "${BATS_TMPDIR}/backupninja.conf"
    setconfig backup.d/test.mysql sqldump no
    setconfig backup.d/test.mysql hotcopy yes
    for databases in app all; do
        setconfig backup.d/test.mysql databases "$databases"
        runaction test.mysql
        [ "$status" -eq 0 ]
        [ "$(cat "${BN_BACKUPDIR}/mysql-host/hotcopy/hotcopy-result")" = hotcopy ]
    done
}

@test "GitLab command and fetch work on a Bash-free Alpine target" {
    runaction test.gitlab
    [ "$status" -eq 0 ]
    [ "$(cat "${BN_BACKUPDIR}/gitlab-host/archive.tar")" = $'create\nCRON=1' ]
}

@test "GitLab failure on Alpine preserves the previous host archive" {
    runaction test.gitlab
    [ "$status" -eq 0 ]
    previous=$(sha256sum "${BN_BACKUPDIR}/gitlab-host/archive.tar")
    setconfig backup.d/test.gitlab transport environment GITLAB_TEST_FAIL=yes
    runaction test.gitlab
    [ "$status" -ne 0 ]
    greplog 'Error: Failed to create GitLab backup'
    [ "$(sha256sum "${BN_BACKUPDIR}/gitlab-host/archive.tar")" = "$previous" ]
}
