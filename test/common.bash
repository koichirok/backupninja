setup() {

    # declare some constants
    readonly BN_REMOTEUSER="backupninja"
    readonly BN_REMOTEHOST="bntest1"
    readonly BN_BACKUPDIR="/var/backups"
    # Used by the handler-specific Bats suites that load this file.
    # shellcheck disable=SC2034
    readonly BN_SRCDIR="/var/cache/bntest"

    # Write a basic backupninja config file
    cat << EOF > "${BATS_TMPDIR}/backupninja.conf"
when = manual
loglevel = 5
reportemail = root
reportsuccess = yes
reportinfo = no
reportwarning = yes
reportspace = no
logfile = ${BATS_TMPDIR}/log/backupninja.log
configdirectory = ${BATS_TMPDIR}/backup.d
scriptdirectory = /usr/share/backupninja
libdirectory = /usr/lib/backupninja
usecolors = no
EOF

    # Create backupninja directories
    mkdir "${BATS_TMPDIR}/log" "${BATS_TMPDIR}/backup.d"
    chmod 0750 "${BATS_TMPDIR}/backup.d"

    # Get name of component being tested
    COMP=$(basename -s .bats "${BATS_TEST_FILENAME}")

    # Invoke component-specific general test setup
    # (runs only before the first test case)
    if [[ "$BATS_TEST_NUMBER" -eq 1 ]]; then
        if type "begin_${COMP}" 2>&1 | grep -q "function"; then
            begin_${COMP}
        fi
    fi

    # Invoke component-specific test setup
    if type "setup_${COMP}" 2>&1 | grep -q "function"; then
        setup_${COMP}
    fi
}

teardown() {

    # Print the debug log in case the test case fails
    if [ -f "${BATS_TMPDIR}/log/backupninja.log" ]; then
        echo "cat ${BATS_TMPDIR}/log/backupninja.log :"
        cat "${BATS_TMPDIR}/log/backupninja.log"
        # Copy logfile so it can be examined in subsequent tests
        cp "${BATS_TMPDIR}/log/backupninja.log" "${BATS_TMPDIR}/_backupninja.log"
    else
        echo "backupninja.log not found"
    fi

    # Clean up
    rm -rf "${BATS_TMPDIR}/backupninja.conf" \
        "${BATS_TMPDIR}/log" \
        "${BATS_TMPDIR}/backup.d" \
        /var/mail/backupninja

    # Invoke component-specific test teardown
    if type "teardown_${COMP}" 2>&1 | grep -q "function"; then
        teardown_${COMP}
    fi

    # Invoke component-specific general test teardown
    # (runs only after the last test case)
    if [[ "${#BATS_TEST_NAMES[@]}" -eq "$BATS_TEST_NUMBER" ]]; then
        if type "finish_${COMP}" 2>&1 | grep -q "function"; then
            finish_${COMP}
        fi
    fi
}

# set parameter/value in action config file
setconfig() {
    if [ -f "${BATS_TMPDIR}/$1" ]; then
        local CONFIGFILE="${BATS_TMPDIR}/$1"
        shift
    else
        local COMP
        COMP=$(basename -s .bats "${BATS_TEST_FILENAME}")
        local CONFIGFILE="${BATS_TMPDIR}/backup.d/test.${COMP}"
    fi
    if [ -n "$3" ]; then
        # named section
        crudini --set -- "$CONFIGFILE" "$1" "$2" "$3"
    else
        # default section
        crudini --set -- "$CONFIGFILE" '' "$1" "$2"
    fi
}

# special-case for repeating config parameters
# crudini doesn't support those
# (used for include and exclude parameters)
setconfig_repeat() {
    if [ -f "${BATS_TMPDIR}/$1" ]; then
        local CONFIGFILE="${BATS_TMPDIR}/$1"
        shift
    else
        local COMP
        COMP=$(basename -s .bats "${BATS_TEST_FILENAME}")
        local CONFIGFILE="${BATS_TMPDIR}/backup.d/test.${COMP}"
    fi
    local SECTION="$1"
    local PARAM="$2"
    shift 2
    crudini --del -- "$CONFIGFILE" "$SECTION" "$PARAM"
    for v; do
        crudini --set --list --list-sep=$'\nREPEAT = ' -- "$CONFIGFILE" "$SECTION" "$PARAM" "$v"
    done
    sed -i "s#^\s\+REPEAT =#${PARAM} =#" "$CONFIGFILE"
}

# delete config parameter
delconfig() {
    if [ -f "${BATS_TMPDIR}/$1" ]; then
        local CONFIGFILE="${BATS_TMPDIR}/$1"
        shift
    else
        local COMP
        COMP=$(basename -s .bats "${BATS_TEST_FILENAME}")
        local CONFIGFILE="${BATS_TMPDIR}/backup.d/test.${COMP}"
    fi
    if [ -n "$2" ]; then
        # named section
        crudini --del -- "$CONFIGFILE" "$1" "$2"
    else
        # default section
        crudini --del -- "$CONFIGFILE" '' "$1"
    fi
}

# execute command on remote test host
remote_command() {
    ssh "${BN_REMOTEUSER}@${BN_REMOTEHOST}" "$1"
}

remote_background_command() {
    ssh -f "${BN_REMOTEUSER}@${BN_REMOTEHOST}" "$1"
}

# remove backup test artifacts
cleanup_backups() {
    for c in "$@"; do
        case "$c" in
            "local")
                grep -q "^tmpfs $BN_BACKUPDIR" /proc/mounts && umount "$BN_BACKUPDIR"
                mount -t tmpfs tmpfs "$BN_BACKUPDIR"
                ;;
            "remote")
                run remote_command "grep -q \"^tmpfs $BN_BACKUPDIR\" /proc/mounts && sudo umount \"$BN_BACKUPDIR\""
                remote_command "sudo mount -t tmpfs tmpfs \"$BN_BACKUPDIR\""
                ;;
        esac
    done
}

# run backupninja action, removing previous log file if exists
runaction() {
    # enable test mode?
    if [ "$1" == "test" ]; then
        local TEST="--test"
        shift
    else
        local TEST=""
    fi
    # get component
    if [ -n "$1" ]; then
        local ACTIONFILE="$1"
    else
        local ACTIONFILE
        ACTIONFILE="test.$(basename -s .bats "${BATS_TEST_FILENAME}")"
    fi
    # run action
    if [ -f "${BATS_TMPDIR}/backup.d/${ACTIONFILE}" ]; then
        [ -f "${BATS_TMPDIR}/log/backupninja.log" ] && rm -f "${BATS_TMPDIR}/log/backupninja.log"
        run backupninja -f "${BATS_TMPDIR}/backupninja.conf" $TEST --debug --now --run "${BATS_TMPDIR}/backup.d/${ACTIONFILE}"
    else
        echo "action file not found: ${BATS_TMPDIR}/backup.d/${ACTIONFILE}"
        false
    fi
}

# run backupninja action in test mode, removing previous log file if exist
testaction() {
    runaction test "$1"
}

# grep the backupninja log
greplog() {
    if [ -z "$2" ]; then
        grep -q "$1" "${BATS_TMPDIR}/log/backupninja.log"
    else
        # grep line following previous match
        grep -A1 "$1" "${BATS_TMPDIR}/log/backupninja.log" | tail -n1 | grep -q -- "$2"
    fi
}


not_greplog() {
    if [ -z "$2" ]; then
        ! grep -q "$1" "${BATS_TMPDIR}/log/backupninja.log"
    else
        # grep line following previous match
        ! (grep -A1 "$1" "${BATS_TMPDIR}/log/backupninja.log" | tail -n1 | grep -q -- "$2")
    fi
}

makegpgkeys() {
    # encryption key
    run gpg --keyid-format long -k encrypt@bntest0 2>/dev/null
    # Bats' run helper sets status.
    # shellcheck disable=SC2154
    if [ "$status" -eq 2 ]; then
        gpg --batch --gen-key <<"        EOF"
            Key-Type: 1
            Key-Length: 2048
            Subkey-Type: 1
            Subkey-Length: 2048
            Name-Real: Encrypt key
            Name-Email: encrypt@bntest0
            Expire-Date: 0
            Passphrase: 123encrypt
        EOF
    fi
    BN_ENCRYPTKEY=$(gpg --keyid-format long -k encrypt@bntest0 | sed -n '2p' | grep -o '\S\+')
    export BN_ENCRYPTKEY
    # signing key
    run gpg --keyid-format long -k sign@bntest0 2>/dev/null
    # shellcheck disable=SC2154
    if [ "$status" -eq 2 ]; then
        gpg --batch --gen-key <<"        EOF"
            Key-Type: 1
            Key-Length: 2048
            Subkey-Type: 1
            Subkey-Length: 2048
            Name-Real: Sign key
            Name-Email: sign@bntest0
            Expire-Date: 0
            Passphrase: 123sign
        EOF
    fi
    BN_SIGNKEY=$(gpg --keyid-format long -k sign@bntest0 | sed -n '2p' | grep -o '\S\+')
    export BN_SIGNKEY
}

# Install a fake podman that runs "exec" against the local system,
# so handlers can be exercised through a container transport without a
# container runtime. Invocations are logged to $BATS_TEST_TMPDIR/runtime.log.
mock_container_runtime() {
    mkdir -p "${BATS_TEST_TMPDIR}/bin"
    cat > "${BATS_TEST_TMPDIR}/bin/podman" <<EOF
#!/bin/bash
printf '%s\n' "\$*" >> '${BATS_TEST_TMPDIR}/runtime.log'
EOF
    cat >> "${BATS_TEST_TMPDIR}/bin/podman" <<'EOF'
case "$1" in
    exec)
        shift
        while [[ "$1" == -* ]]; do
            case "$1" in
                --user|--workdir|--env) shift 2 ;;
                *) shift ;;
            esac
        done
        shift # container
        exec "$@"
        ;;
esac
exit 1
EOF
    chmod +x "${BATS_TEST_TMPDIR}/bin/podman"
    export PATH="${BATS_TEST_TMPDIR}/bin:$PATH"
}

install_pkgs() {
    TMPDIR=/tmp DEBIAN_FRONTEND=noninteractive apt-get -qq install "$@"
}

make_rootfs() {
    command -v mmdebstrap >/dev/null || install_pkgs mmdebstrap
    mmdebstrap "$1" "$2" --aptopt='Acquire::https::Proxy "DIRECT"' --dpkgopt=force-unsafe-io --variant=minbase
}
