load common

setup_transport() {
    libdirectory="${BATS_TEST_DIRNAME}/../lib"
    . "$libdirectory/tools"
    setfile "${BATS_TEST_TMPDIR}/transport.conf"
    setsection ""
    debug() { :; }
    fatal() { echo "Fatal: $*" >&2; exit 2; }
    mkdir -p "${BATS_TEST_TMPDIR}/bin"
    export PATH="${BATS_TEST_TMPDIR}/bin:$PATH"
}

write_mock_runtime() {
    cat > "${BATS_TEST_TMPDIR}/bin/$1" <<'EOF'
#!/bin/bash
printf '%s\n' "$@" >> "$TRANSPORT_LOG"
if [ "$1" = compose ] && [ "$2" = config ] && [ "$3" = --services ]; then
    echo database
elif [ "$1" = compose ] && [ "$2" = ps ] && [ "$3" = -q ]; then
    echo container-id
fi
EOF
    chmod +x "${BATS_TEST_TMPDIR}/bin/$1"
}

@test "local transport executes commands without a wrapper" {
    cat > "${BATS_TEST_TMPDIR}/transport.conf" <<EOF
[transport]
transport = local
EOF

    transport_init
    run runcmd printf '%s' 'value with spaces'

    [ "$status" -eq 0 ]
    [ "$output" = 'value with spaces' ]
}

@test "podman transport preserves execution options as arguments" {
    export TRANSPORT_LOG="${BATS_TEST_TMPDIR}/transport.log"
    write_mock_runtime podman
    cat > "${BATS_TEST_TMPDIR}/transport.conf" <<EOF
[transport]
transport = podman
container = database container
user = postgres
workdir = /var/lib/postgresql data
environment = MODE=backup value
EOF

    transport_init
    runcmd command 'argument with spaces'

    run grep -Fx 'database container' "$TRANSPORT_LOG"
    [ "$status" -eq 0 ]
    run grep -Fx '/var/lib/postgresql data' "$TRANSPORT_LOG"
    [ "$status" -eq 0 ]
    run grep -Fx 'MODE=backup value' "$TRANSPORT_LOG"
    [ "$status" -eq 0 ]
    run grep -Fx 'argument with spaces' "$TRANSPORT_LOG"
    [ "$status" -eq 0 ]
}

@test "docker compose validates the service and wraps commands" {
    export TRANSPORT_LOG="${BATS_TEST_TMPDIR}/transport.log"
    write_mock_runtime docker
    mkdir "${BATS_TEST_TMPDIR}/compose project"
    cat > "${BATS_TEST_TMPDIR}/transport.conf" <<EOF
[transport]
transport = docker-compose
projectdir = ${BATS_TEST_TMPDIR}/compose project
service = database
EOF

    transport_init
    runcmd command argument

    grep -Fxq compose "$TRANSPORT_LOG"
    grep -Fxq exec "$TRANSPORT_LOG"
    grep -Fxq -- -T "$TRANSPORT_LOG"
    grep -Fxq database "$TRANSPORT_LOG"
}

@test "docker compose service validation uses exact names" {
    export TRANSPORT_LOG="${BATS_TEST_TMPDIR}/transport.log"
    write_mock_runtime docker
    mkdir "${BATS_TEST_TMPDIR}/compose"
    cat > "${BATS_TEST_TMPDIR}/transport.conf" <<EOF
[transport]
transport = docker-compose
projectdir = ${BATS_TEST_TMPDIR}/compose
service = data.*
EOF

    run transport_init

    [ "$status" -eq 2 ]
    [[ "$output" = *"Service 'data.*' does not exist"* ]]
}

write_tar_runtime() {
    # exec runs tar locally; FAIL_TAR makes the transfer fail midway
    cat > "${BATS_TEST_TMPDIR}/bin/$1" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >> "$TRANSPORT_LOG"
[ "$1" = exec ] || exit 0
shift
while [[ "$1" == -* ]]; do shift; done
shift
if [ -n "$FAIL_TAR" ]; then
    printf 'garbage'
    exit 1
fi
exec "$@"
EOF
    chmod +x "${BATS_TEST_TMPDIR}/bin/$1"
}

@test "container transport fetches into an explicit host directory" {
    export TRANSPORT_LOG="${BATS_TEST_TMPDIR}/transport.log"
    write_tar_runtime docker
    mkdir -p "${BATS_TEST_TMPDIR}/remote/sub"
    echo new > "${BATS_TEST_TMPDIR}/remote/db.sql"
    echo nested > "${BATS_TEST_TMPDIR}/remote/sub/x.sql"
    ln -s /etc/passwd "${BATS_TEST_TMPDIR}/remote/link"
    cat > "${BATS_TEST_TMPDIR}/transport.conf" <<EOF
[transport]
transport = docker
container = database
hostbackupdir = ${BATS_TEST_TMPDIR}/host backup
EOF

    transport_init
    warning() { echo "Warning: $*" >> "${BATS_TEST_TMPDIR}/warnings"; }
    transport_finalize "${BATS_TEST_TMPDIR}/remote"

    grep -Fxq "exec -i database tar -cf - -C ${BATS_TEST_TMPDIR}/remote ." "$TRANSPORT_LOG"
    [ "$(cat "${BATS_TEST_TMPDIR}/host backup/db.sql")" = new ]
    [ "$(cat "${BATS_TEST_TMPDIR}/host backup/sub/x.sql")" = nested ]
    [ ! -e "${BATS_TEST_TMPDIR}/host backup/link" ]
    grep -q "Not installing 'link'" "${BATS_TEST_TMPDIR}/warnings"
    [ -z "$(ls -A "${BATS_TEST_TMPDIR}/host backup" | grep backupninja-fetch)" ]
}

@test "failed fetch keeps previous host backups" {
    export TRANSPORT_LOG="${BATS_TEST_TMPDIR}/transport.log" FAIL_TAR=1
    write_tar_runtime docker
    mkdir -p "${BATS_TEST_TMPDIR}/remote" "${BATS_TEST_TMPDIR}/host"
    echo new > "${BATS_TEST_TMPDIR}/remote/db.sql"
    echo previous > "${BATS_TEST_TMPDIR}/host/db.sql"
    cat > "${BATS_TEST_TMPDIR}/transport.conf" <<EOF
[transport]
transport = docker
container = database
hostbackupdir = ${BATS_TEST_TMPDIR}/host
EOF

    transport_init
    run transport_finalize "${BATS_TEST_TMPDIR}/remote"

    [ "$status" -eq 2 ]
    [[ "$output" = *"previous backups were left unchanged"* ]]
    [ "$(cat "${BATS_TEST_TMPDIR}/host/db.sql")" = previous ]
    [ "$(ls -A "${BATS_TEST_TMPDIR}/host")" = db.sql ]
}

@test "fetch is skipped in test mode" {
    export TRANSPORT_LOG="${BATS_TEST_TMPDIR}/transport.log"
    write_tar_runtime docker
    cat > "${BATS_TEST_TMPDIR}/transport.conf" <<EOF
[transport]
transport = docker
container = database
hostbackupdir = ${BATS_TEST_TMPDIR}/host
EOF

    transport_init
    test=1 transport_finalize /nonexistent

    [ ! -e "${BATS_TEST_TMPDIR}/host" ]
    ! grep -q tar "$TRANSPORT_LOG"
}

@test "shellquote protects shell metacharacters" {
    value="it's \$(echo bad); \`x\` \"q\""
    [ "$(sh -c "printf '%s' $(shellquote "$value")")" = "$value" ]
}

@test "POSIX dump script handles quoted paths and replaces output on success" {
    target="${BATS_TEST_TMPDIR}/it's a backup.sql"
    script=$(transport_dump_command "printf '%s' complete" "$target" no)
    run sh -c "$script"
    [ "$status" -eq 0 ]
    [ "$(cat "$target")" = complete ]
}

@test "POSIX compressed dump detects producer failure and preserves output" {
    target="${BATS_TEST_TMPDIR}/db.sql.gz"
    echo previous > "$target"
    GZIP=gzip GZIP_OPTS=""
    script=$(transport_dump_command "( printf partial; exit 1 )" "$target" yes)
    run sh -c "$script"
    [ "$status" -ne 0 ]
    [ "$(cat "$target")" = previous ]
    [ ! -e "${BATS_TEST_TMPDIR}/.db.sql.gz.partial" ]
}

@test "POSIX compressed dump detects compressor failure and preserves output" {
    target="${BATS_TEST_TMPDIR}/db.sql.gz"
    echo previous > "$target"
    GZIP=false GZIP_OPTS=""
    script=$(transport_dump_command "printf complete" "$target" yes)
    run sh -c "$script"
    [ "$status" -ne 0 ]
    [ "$(cat "$target")" = previous ]
    [ ! -e "${BATS_TEST_TMPDIR}/.db.sql.gz.partial" ]
}

@test "POSIX dump propagates an early failure in a multi-part producer" {
    target="${BATS_TEST_TMPDIR}/db.sql"
    echo previous > "$target"
    script=$(transport_dump_command "( false && printf structure )" "$target" no)
    run sh -c "$script"
    [ "$status" -ne 0 ]
    [ "$(cat "$target")" = previous ]
}

@test "unsupported transports fail during initialization" {
    cat > "${BATS_TEST_TMPDIR}/transport.conf" <<EOF
[transport]
transport = teleport
EOF

    run transport_init

    [ "$status" -eq 2 ]
    [[ "$output" = *"Unsupported transport 'teleport'"* ]]
}
