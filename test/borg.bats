load common

begin_borg() {
    install_pkgs borgbackup
    if [ ! -d "$BN_SRCDIR" ]; then
        make_rootfs testing "$BN_SRCDIR"
    fi
}

setup_borg() {
    cat << EOF > "${BATS_TMPDIR}/backup.d/test.borg"
when = manual
testconnect = no
nicelevel = 0
ionicelevel =
bwlimit =

[source]
init = yes
include = ${BN_SRCDIR}
exclude = ${BN_SRCDIR}/var
create_options =
prune = yes
keep = 30d
prune_options =
cache_directory =

[dest]
user =
host = localhost
directory = ${BN_BACKUPDIR}/testborg
archive =
compression = lz4
encryption = none
passphrase =
EOF

    chmod 0640 "${BATS_TMPDIR}/backup.d/test.borg"
    rm -rf /root/.cache/borg
}

finish_borg() {
    cleanup_backups local remote
    rm -rf /root/.cache/borg
}

@test "check ssh connection test" {
    setconfig testconnect yes
    setconfig dest user $BN_REMOTEUSER
    setconfig dest host $BN_REMOTEHOST
    testaction
    greplog "Debug: Connected to ${BN_REMOTEHOST} as ${BN_REMOTEUSER} successfully$"
}

@test "check config parameter nicelevel" {
    # nicelevel is 0 by default
    delconfig nicelevel
    testaction
    greplog 'Debug: executing borg create$' '\bnice -n 0\b'

    # nicelevel is defined
    setconfig nicelevel -19
    testaction
    greplog 'Debug: executing borg create$' '\bnice -n -19\b'
}

@test "check config parameter ionicelevel" {
    # no ionice by default
    delconfig ionicelevel
    testaction
    not_greplog 'Debug: executing borg create$' '\bionice -c2\b'

    # acceptable value
    setconfig ionicelevel 7
    testaction
    greplog 'Debug: executing borg create$' '\bionice -c2 -n 7\b'

    # unacceptable value
    setconfig ionicelevel 10
    testaction
    greplog 'Fatal: The value of ionicelevel is expected to be either empty or an integer from 0 to 7. Got: 10$'
}

@test "check config parameter bwlimit" {
    # no limit by default
    delconfig bwlimit
    testaction
    not_greplog 'Debug: executing borg create$' '\s--remote-ratelimit='

    # limit is defined
    setconfig bwlimit 1024
    testaction
    greplog 'Debug: executing borg create$' '\s--remote-ratelimit=1024\b'

}

@test "check config parameter source/init" {
    # do repository init by default
    delconfig source init
    testaction
    greplog 'Debug: executing borg init$'

    # do repository init 
    setconfig source init yes
    testaction
    greplog 'Debug: executing borg init$'

    # don't do repository init 
    setconfig source init no
    testaction
    not_greplog 'Debug: executing borg init$'
}

@test "check config parameter source/include" {
    # missing path
    delconfig source include
    testaction
    greplog 'Fatal: No source includes specified$'

    # single path
    setconfig source include "$BN_SRCDIR"
    testaction
    greplog 'Debug: executing borg create$' "'${BN_SRCDIR}'$"

    # multiple paths
    setconfig_repeat source include "$BN_SRCDIR" /foo /bar
    testaction
    greplog 'Debug: executing borg create$' "'${BN_SRCDIR}' '/foo' '/bar'$"
}

@test "check config parameter source/exclude" {
    # absent path
    delconfig source exclude
    testaction
    not_greplog 'Debug: executing borg create$' "\s--exclude\s"

    # single path
    setconfig source exclude "${BN_SRCDIR}/var"
    testaction
    greplog 'Debug: executing borg create$' "\s--exclude '${BN_SRCDIR}/var'\s"

    # multiple paths
    setconfig_repeat source exclude "$BN_SRCDIR/var" "$BN_SRCDIR/foo" "$BN_SRCDIR/bar"
    testaction
    greplog 'Debug: executing borg create$' "\s--exclude '${BN_SRCDIR}/var' --exclude '${BN_SRCDIR}/foo' --exclude '${BN_SRCDIR}/bar'\s"
}

@test "check config parameter source/create_options" {
    # absent parameter
    delconfig source create_options
    testaction
    greplog 'Debug: executing borg create$' "\sborg create --stats --compression lz4\s\+--exclude\s"

    # defined parameter
    setconfig source create_options "-x --exclude-caches"
    testaction
    greplog 'Debug: executing borg create$' "\s\+-x --exclude-caches\s\+"
}

@test "check config parameter source/prune" {
    # absent parameter, defaults enabled
    delconfig source prune
    testaction
    greplog 'Debug: executing borg prune$'

    # defined parameter, enabled
    setconfig source prune yes
    testaction
    greplog 'Debug: executing borg prune$'

    # defined parameter, disabled
    setconfig source prune no
    testaction
    not_greplog 'Debug: executing borg prune$'
}

@test "check config parameter source/keep" {
    # absent parameter, defaults to '30d'
    setconfig source prune yes
    delconfig source keep
    testaction
    greplog 'Debug: executing borg prune$' '\s--keep-within=30d\b'

    # defined parameter, set to 60d
    setconfig source prune yes
    setconfig source keep 60d
    testaction
    greplog 'Debug: executing borg prune$' '\s--keep-within=60d\b'

    # defined parameter, disabled, set to 0
    setconfig source prune yes
    setconfig source keep 0
    testaction
    not_greplog 'Debug: executing borg prune$' '\s--keep-within='
}

@test "check config parameter source/prune_options" {
    # absent parameter
    delconfig source prune_options
    testaction
    greplog 'Debug: executing borg prune$' "Debug: borg prune  --keep-within=30d ${BN_BACKUPDIR}/testborg$"

    # defined parameter
    setconfig source prune_options "--keep-daily 9 --save-space"
    testaction
    greplog 'Debug: executing borg prune$' "\s\+--keep-daily 9 --save-space\s\+"
}

@test "check config parameter source/cache_directory" {
    # absent parameter
    delconfig source cache_directory
    testaction
    not_greplog 'Debug: export BORG_CACHE_DIR='

    # defined parameter
    setconfig source cache_directory "/var/cache/borg"
    testaction
    greplog 'Debug: export BORG_CACHE_DIR="/var/cache/borg"$'
}

@test "check config parameter source/filter_warnings" {
    delconfig source include
    setconfig_repeat source include "$BN_SRCDIR/boot" "$BN_SRCDIR/etc" "$BN_SRCDIR/lib" "$BN_SRCDIR/var" "$BN_SRCDIR/foo"
    setconfig source filter_warnings yes
    setconfig dest archive testarchive
    setconfig dest encryption none
    setconfig dest compression zstd,16
    delconfig dest passphrase
    cleanup_backups local
    runaction
    greplog "Info: Backing up source finished with missing file warnings."
}

@test "check config parameter dest/user" {
    # absent parameter
    delconfig dest user
    setconfig dest host "$BN_REMOTEHOST"
    testaction
    greplog 'Fatal: Destination user not set$'

    # defined parameter
    setconfig dest user "$BN_REMOTEUSER"
    setconfig dest host "$BN_REMOTEHOST"
    testaction
    greplog "Debug: ssh\s\+-o PasswordAuthentication=no ${BN_REMOTEHOST} -l ${BN_REMOTEUSER} 'echo -n 1'"
    greplog 'Debug: executing borg create$' "\bssh://${BN_REMOTEUSER}@${BN_REMOTEHOST}${BN_BACKUPDIR}/testborg::"
}

@test "check config parameter dest/host" {
    # absent parameter
    delconfig dest host
    setconfig dest user "$BN_REMOTEUSER"
    testaction
    greplog 'Fatal: Destination host not set$'

    # defined parameter
    setconfig dest user "$BN_REMOTEUSER"
    setconfig dest host "$BN_REMOTEHOST"
    testaction
    greplog "Debug: ssh\s\+-o PasswordAuthentication=no ${BN_REMOTEHOST} -l ${BN_REMOTEUSER} 'echo -n 1'"
    greplog 'Debug: executing borg create$' "\bssh://${BN_REMOTEUSER}@${BN_REMOTEHOST}${BN_BACKUPDIR}/testborg::"
}

@test "check config parameter dest/port" {
    # absent parameter, port not specified
    setconfig dest user "$BN_REMOTEUSER"
    setconfig dest host "$BN_REMOTEHOST"
    delconfig dest port
    testaction
    greplog "Debug: ssh\s\+-o PasswordAuthentication=no ${BN_REMOTEHOST} -l ${BN_REMOTEUSER} 'echo -n 1'"
    greplog 'Debug: executing borg create$' "\bssh://${BN_REMOTEUSER}@${BN_REMOTEHOST}${BN_BACKUPDIR}/testborg::"

    # defined parameter
    setconfig dest port 7722
    setconfig dest user "$BN_REMOTEUSER"
    setconfig dest host "$BN_REMOTEHOST"
    testaction
    greplog "Debug: ssh\s\+-o PasswordAuthentication=no ${BN_REMOTEHOST} -p 7722 -l ${BN_REMOTEUSER} 'echo -n 1'"
    greplog 'Debug: executing borg create$' "\bssh://${BN_REMOTEUSER}@${BN_REMOTEHOST}:7722${BN_BACKUPDIR}/testborg::"
}

@test "check config parameter dest/directory" {
    # absent parameter
    delconfig dest directory
    testaction
    greplog 'Fatal: Destination directory not set$'

    # defined parameter
    setconfig dest directory "${BN_BACKUPDIR}/testborg"
    testaction
    greplog 'Debug: executing borg create$' "\s${BN_BACKUPDIR}/testborg::"
}

@test "check config parameter dest/archive" {
    # absent parameter, defaults to {now:%Y-%m-%dT%H:%M:%S}
    delconfig dest archive
    testaction
    greplog 'Debug: executing borg create$' "\s${BN_BACKUPDIR}/testborg::{now:%Y-%m-%dT%H:%M:%S}"

    # defined parameter
    setconfig dest archive foo
    testaction
    greplog 'Debug: executing borg create$' "\s${BN_BACKUPDIR}/testborg::foo"
}

@test "check config parameter dest/compression" {
    # absent parameter, defaults to lz4
    delconfig dest compression
    testaction
    greplog 'Debug: executing borg create$' "\s--compression lz4\b"

    # defined parameter
    setconfig dest compression auto,zstd,13
    testaction
    greplog 'Debug: executing borg create$' "\s--compression auto,zstd,13\b"
}

@test "check config parameter dest/sshoptions" {
    # undefined parameter
    setconfig dest user $BN_REMOTEUSER
    setconfig dest host $BN_REMOTEHOST
    delconfig dest sshoptions
    testaction
    not_greplog "Debug: export BORG_RSH="
    greplog "Debug: ssh\s\+-o PasswordAuthentication=no\s"
    greplog "Debug: Connected to ${BN_REMOTEHOST} as ${BN_REMOTEUSER} successfully$"

    # defined parameter
    setconfig dest user $BN_REMOTEUSER
    setconfig dest host $BN_REMOTEHOST
    setconfig dest sshoptions "-i /root/.ssh/id_ed25519"
    testaction
    greplog "Debug: export BORG_RSH=\"ssh -i /root/.ssh/id_ed25519\"$"
    greplog "Debug: ssh -i /root/.ssh/id_ed25519 -o PasswordAuthentication=no\s"
    greplog "Debug: Connected to ${BN_REMOTEHOST} as ${BN_REMOTEUSER} successfully$"
}

@test "create local backup without encryption" {
    # no encryption, no passphrase
    setconfig dest archive testarchive
    setconfig dest encryption none
    delconfig dest passphrase
    cleanup_backups local
    runaction
    greplog 'Debug: executing borg init$' 'Debug: borg init --encryption=none'
    greplog "Warning: Repository has been initialized"
}

@test "verify local backup without encryption" {
    unset BORG_PASSPHRASE
    borg extract --dry-run "${BN_BACKUPDIR}/testborg::testarchive"
}

@test "create local backup with encryption" {
    # encryption enabled, wrong passphrase
    setconfig dest archive testarchive
    setconfig dest encryption repokey
    setconfig dest passphrase 123test
    cleanup_backups local
    runaction
    greplog 'Debug: executing borg init$' 'Debug: borg init --encryption=repokey'
    greplog "Warning: Repository has been initialized"
}

@test "verify local backup with encryption" {
    export BORG_PASSPHRASE="123foo"
    run borg extract --dry-run "${BN_BACKUPDIR}/testborg::testarchive"
    [ "$status" -eq 2 ]
    export BORG_PASSPHRASE="123test"
    borg extract --dry-run "${BN_BACKUPDIR}/testborg::testarchive"
}

@test "create remote backup with encryption" {
    setconfig dest archive testarchive
    setconfig dest encryption repokey
    setconfig dest passphrase 123test
    setconfig dest host "${BN_REMOTEHOST}"
    setconfig dest user "${BN_REMOTEUSER}"
    cleanup_backups remote
    runaction
    greplog 'Debug: executing borg init$' 'Debug: borg init --encryption=repokey'
    greplog "Warning: Repository has been initialized"
}

@test "verify remote backup with encryption" {
    export BORG_PASSPHRASE="123foo"
    run borg extract --dry-run "ssh://${BN_REMOTEUSER}@${BN_REMOTEHOST}${BN_BACKUPDIR}/testborg::testarchive"
    [ "$status" -eq 2 ]
    export BORG_PASSPHRASE="123test"
    borg extract --dry-run "ssh://${BN_REMOTEUSER}@${BN_REMOTEHOST}${BN_BACKUPDIR}/testborg::testarchive"
}
