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

@test "container transport fetches into an explicit host directory" {
    export TRANSPORT_LOG="${BATS_TEST_TMPDIR}/transport.log"
    write_mock_runtime docker
    cat > "${BATS_TEST_TMPDIR}/transport.conf" <<EOF
[transport]
transport = docker
container = database
hostbackupdir = ${BATS_TEST_TMPDIR}/host backup
EOF

    transport_init
    transport_finalize '/var/backups/postgres'

    [ -d "${BATS_TEST_TMPDIR}/host backup" ]
    grep -Fxq cp "$TRANSPORT_LOG"
    grep -Fxq 'database:/var/backups/postgres/.' "$TRANSPORT_LOG"
    grep -Fxq "${BATS_TEST_TMPDIR}/host backup/" "$TRANSPORT_LOG"
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
