load common

begin_restic() {
    if [ ! -d "$BN_SRCDIR" ]; then
        make_rootfs testing "$BN_SRCDIR"
    fi

    command -v restic >/dev/null || \
        install_pkgs restic

    remote_install_pkgs restic wget
    remote_command_root "wget -q https://github.com/restic/rest-server/releases/download/v0.14.0/rest-server_0.14.0_linux_amd64.tar.gz -O - | tar -xz -C /usr/local/bin --strip-components=1"
    remote_background_command "/usr/local/bin/rest-server --no-auth --path ${BN_BACKUPDIR}"
}

setup_restic() {
    export RESTICREPO="${BN_BACKUPDIR}/testrestic"

    cat << EOF > "${BATS_TMPDIR}/backup.d/test.restic"
when = manual

[general]
nicelevel =
ionicelevel =
repository = ${RESTICREPO}
password = 123test
run_backup = yes

[backup]
init = yes
include = ${BN_SRCDIR}
exclude = ${BN_SRCDIR}/var
EOF

    chmod 0640 "${BATS_TMPDIR}/backup.d/test.restic"
    rm -rf /root/.cache/restic
}

finish_restic() {
    remote_command 'kill $(pgrep -u 1000 rest-server)'
    cleanup_backups local remote
    rm -rf /root/.cache/restic
}

init_repo() {
    if [ "$1" = "remote" ]; then
        cleanup_backups remote
        remote_command "restic init --repo ${RESTICREPO} <<<123test"
    else
        cleanup_backups local
        restic init --repo "${RESTICREPO}" <<<123test
    fi
}

@test "check connection test, local repository" {
    local badrepo="${BN_BACKUPDIR}foo/bar"
    local goodrepo="${RESTICREPO}"

    # invalid repo
    setconfig general repository "$badrepo"
    setconfig backup init no
    testaction
    greplog "Info: Attempting to connect to repository at ${badrepo}$"
    greplog "Fatal: The specified repository is absent or unusable!$"

    # valid repo
    init_repo local
    setconfig general repository "${goodrepo}"
    setconfig backup init no
    testaction
    greplog "Info: Attempting to connect to repository at ${goodrepo}$"
    greplog "Info: Connected successfully.$"
}

@test "check connection test, rest repository" {
    local badrepo="rest:http://foo@bar:8000/testrestic"
    local okrepo="rest:http://${BN_REMOTEUSER}@${BN_REMOTEHOST}:8000/testrestic"

    # invalid repo
    setconfig general repository "$badrepo"
    setconfig backup init no
    testaction
    greplog "Info: Attempting to connect to repository at ${badrepo}$"
    greplog "Fatal: The specified repository is absent or unusable!$"

    # valid repo
    init_repo remote
    setconfig general repository "${okrepo}"
    setconfig backup init no
    testaction
    greplog "Info: Attempting to connect to repository at ${okrepo}$"
    greplog "Info: Connected successfully.$"
}

@test "check config parameter general/nicelevel" {
    # nicelevel is 0 by default
    delconfig general nicelevel
    testaction
    not_greplog 'Debug: executing restic backup$' '\bnice -n\b'

    # nicelevel is defined
    setconfig general nicelevel -19
    testaction
    greplog 'Debug: executing restic backup$' '\bnice -n -19\b'
}

@test "check config parameter general/ionicelevel" {
    # no ionice by default
    delconfig general ionicelevel
    testaction
    not_greplog 'Debug: executing restic backup$' '\bionice -c2\b'

    # acceptable value
    setconfig general ionicelevel 7
    testaction
    greplog 'Debug: executing restic backup$' '\bionice -c2 -n 7\b'

    # unacceptable value
    setconfig general ionicelevel 10
    testaction
    greplog 'Fatal: The value of ionicelevel is expected to be either empty or an integer from 0 to 7. Got: 10$'
}

@test "check config parameter backup/include" {
    local cmd="restic backup --repo ${RESTICREPO}"

    # undefined, raises fatal error
    delconfig backup include
    testaction
    greplog "Fatal: No files or directories specified for backup.$"

    # single value
    setconfig backup include "$BN_SRCDIR"
    testaction
    greplog 'Debug: executing restic backup$' "\b${cmd} '${BN_SRCDIR}'\s"

    # mutliple values
    setconfig_repeat backup include "$BN_SRCDIR" "/home"
    testaction
    greplog 'Debug: executing restic backup$' "\b${cmd} '${BN_SRCDIR}' '/home'\s"

    # with spaces
    delconfig backup include
    setconfig backup include "/home/foo/My Documents"
    testaction
    cat ${BATS_TMPDIR}/backup.d/test.restic
    greplog 'Debug: executing restic backup$' "\b${cmd} '/home/foo/My Documents'\s"

    # with glob (though restic doesn't support it)
    delconfig backup include
    setconfig backup include "/etc/*"
    testaction
    cat ${BATS_TMPDIR}/backup.d/test.restic
    greplog 'Debug: executing restic backup$' "\b${cmd} '/etc/\*'\s"
}

@test "check config parameter backup/exclude" {
    local cmd="restic backup --repo ${RESTICREPO} '${BN_SRCDIR}' --exclude ${RESTICREPO}"

    # undefined
    delconfig backup exclude
    testaction
    greplog 'Debug: executing restic backup$' "${cmd}"

    # single value
    setconfig backup exclude "${BN_SRCDIR}/var"
    testaction
    greplog 'Debug: executing restic backup$' "\b${cmd} --exclude '${BN_SRCDIR}/var'"

    # mutliple values
    setconfig_repeat backup exclude "${BN_SRCDIR}/var" "/home"
    testaction
    greplog 'Debug: executing restic backup$' "\b${cmd} --exclude '${BN_SRCDIR}/var' --exclude '/home'"

    # with spaces
    delconfig backup exclude
    setconfig backup exclude "/home/foo/My Documents"
    testaction
    cat ${BATS_TMPDIR}/backup.d/test.restic
    greplog 'Debug: executing restic backup$' "\b${cmd} --exclude '/home/foo/My Documents'"

    # with glob (though restic doesn't support it)
    delconfig backup exclude
    setconfig backup exclude "/etc/*"
    testaction
    cat ${BATS_TMPDIR}/backup.d/test.restic
    greplog 'Debug: executing restic backup$' "\b${cmd} --exclude '/etc/\*'"
}

@test "run local backup" {
    init_repo
    setconfig general run_backup yes
    runaction
    greplog 'Info: Restic backup successful.$'
}

@test "run local forget" {
    setconfig general run_forget yes
    runaction
    greplog 'Info: Restic forget successful.$'
}

@test "run local prune" {
    setconfig general run_prune yes
    runaction
    greplog 'Info: Restic prune successful.$'
}

@test "run local check" {
    setconfig general run_check yes
    runaction
    greplog 'Info: Restic check successful.$'
}

@test "run remote backup" {
    local remote="http://${BN_REMOTEUSER}@${BN_REMOTEHOST}:8000/testrestic"
    setconfig general repository "rest:${remote}"
    setconfig general run_backup yes
    runaction
    greplog 'Info: Restic backup successful.$'
}
