load ../common

setup() {
    export MOCK_LOG="$BATS_TEST_TMPDIR/commands"
    export MOCK_EXIT=0
    export MOCK_START_EXIT=0
    export MOCK_COPY_EXIT=0
    export BN_TEST_RESULTS="$BATS_TEST_TMPDIR/results"
    export BN_TEST_SKIP_BUILD=1
    mkdir "$BATS_TEST_TMPDIR/bin"
    export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
    cat > "$BATS_TEST_TMPDIR/bin/docker" <<'EOF'
#!/bin/bash
echo "$*" >> "$MOCK_LOG"
case "$1" in
    create) echo test-container ;;
    inspect) echo "$MOCK_EXIT" ;;
    start) exit "$MOCK_START_EXIT" ;;
    cp) exit "$MOCK_COPY_EXIT" ;;
esac
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/docker"
}

teardown() {
    :
}

@test "Docker runner propagates guest test failures and retrieves logs" {
    export MOCK_EXIT=1
    run bash "$BATS_TEST_DIRNAME/../docker.sh" sys
    [ "$status" -eq 1 ]
    grep -q '^cp test-container:/results/.' "$MOCK_LOG"
    grep -q '^rm -f test-container$' "$MOCK_LOG"
}

@test "Docker runner succeeds only when the container succeeds" {
    run bash "$BATS_TEST_DIRNAME/../docker.sh" sh
    [ "$status" -eq 0 ]
    grep -q '^inspect ' "$MOCK_LOG"
}

@test "Docker runner cleans up after an attach failure" {
    export MOCK_START_EXIT=125
    run bash "$BATS_TEST_DIRNAME/../docker.sh" sh
    [ "$status" -eq 125 ]
    grep -q '^cp ' "$MOCK_LOG"
    grep -q '^rm -f ' "$MOCK_LOG"
}

@test "Docker runner reports log-copy failures" {
    export MOCK_COPY_EXIT=1
    run bash "$BATS_TEST_DIRNAME/../docker.sh" sh
    [ "$status" -eq 1 ]
    [[ "$output" == *"Failed to retrieve VM logs."* ]]
    grep -q '^rm -f ' "$MOCK_LOG"
}

@test "Docker runner rejects unknown handlers before Docker operations" {
    run bash "$BATS_TEST_DIRNAME/../docker.sh" ../sys
    [ "$status" -eq 2 ]
    [ ! -e "$MOCK_LOG" ]
}

@test "Docker runner exposes only KVM when explicitly requested" {
    export BN_TEST_KVM=1
    run bash "$BATS_TEST_DIRNAME/../docker.sh" sys
    [ "$status" -eq 0 ]
    grep -q '^create --init --device /dev/kvm backupninja-tests sys$' "$MOCK_LOG"
}

prepare_suite() {
    [ "$EUID" -eq 0 ] || skip "Suite runner requires root"
    for command in backupninja apt-get mount umount bats; do
        cat > "$BATS_TEST_TMPDIR/bin/$command" <<'EOF'
#!/bin/bash
echo "$(basename "$0") $*" >> "$MOCK_LOG"
case "$(basename "$0")" in
    bats)
        [[ "$*" != *sh.bats ]] || exit "$MOCK_EXIT"
        ;;
    mount)
        [[ "$*" != *'/var/backups' ]] || exit "${MOCK_MOUNT_EXIT:-0}"
        ;;
esac
EOF
        chmod +x "$BATS_TEST_TMPDIR/bin/$command"
    done
    export TMPDIR="$BATS_TEST_TMPDIR"
}

run_suite() {
    run bash -c 'printf y | bash "$@"' bash "$BATS_TEST_DIRNAME/../test.sh" "$@"
}

@test "Suite runner retains failures, runs remaining handlers, and unmounts" {
    prepare_suite
    export MOCK_EXIT=1
    run_suite sh sys
    [ "$status" -eq 1 ]
    grep -q '^bats .*sh.bats$' "$MOCK_LOG"
    grep -q '^bats .*sys.bats$' "$MOCK_LOG"
    [ "$(grep -c '^umount ' "$MOCK_LOG")" -eq 2 ]
    [ -z "$(find "$BATS_TEST_TMPDIR" -maxdepth 1 -name 'bntest.*' -print)" ]
}

@test "Suite runner succeeds and cleans up after passing tests" {
    prepare_suite
    run_suite sh
    [ "$status" -eq 0 ]
    [ "$(grep -c '^umount ' "$MOCK_LOG")" -eq 2 ]
}

@test "Suite runner cleans up partial mount setup" {
    prepare_suite
    export MOCK_MOUNT_EXIT=1
    run_suite sh
    [ "$status" -eq 1 ]
    [ "$(grep -c '^umount ' "$MOCK_LOG")" -eq 1 ]
    ! grep -q '^umount /var/backups$' "$MOCK_LOG"
    ! grep -q '^bats ' "$MOCK_LOG"
}

@test "Suite runner rejects unknown handlers without installing or mounting" {
    prepare_suite
    run_suite ../sys
    [ "$status" -eq 2 ]
    [ ! -e "$MOCK_LOG" ]
}

@test "Config helper preserves global and section values with leading dashes" {
    BATS_TMPDIR="$BATS_TEST_TMPDIR"
    touch "$BATS_TMPDIR/config"
    setconfig config reportwarning no
    setconfig config admingroup staff
    setconfig config general nicelevel -19
    [ "$(crudini --get "$BATS_TMPDIR/config" '' reportwarning)" == no ]
    [ "$(crudini --get "$BATS_TMPDIR/config" '' admingroup)" == staff ]
    [ "$(crudini --get "$BATS_TMPDIR/config" general nicelevel)" == -19 ]
}

@test "Config helper preserves repeated dash-prefixed patterns" {
    BATS_TMPDIR="$BATS_TEST_TMPDIR"
    touch "$BATS_TMPDIR/config"
    setconfig_repeat config backup exclude '-cache' '-tmp'
    grep -q '^exclude = -cache$' "$BATS_TMPDIR/config"
    grep -q '^exclude = -tmp$' "$BATS_TMPDIR/config"
    delconfig config backup exclude
    ! grep -q '^exclude' "$BATS_TMPDIR/config"
}
