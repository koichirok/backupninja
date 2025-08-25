load common

begin_rdiff() {
    install_pkgs rdiff-backup cstream
    if [ ! -d "$BN_SRCDIR" ]; then
        make_rootfs testing "$BN_SRCDIR"
    fi
}

setup_rdiff() {
    cat << EOF > "${BATS_TMPDIR}/backup.d/test.rdiff"
when = manual
options =
nicelevel =
testconnect = no
bwlimit = 
ignore_version =
output_as_info =
keep = yes

[source]
label = testrdiff
type = local
keep = yes
include = ${BN_SRCDIR}
exclude = ${BN_SRCDIR}/var

[dest]
type = local
directory = $BN_BACKUPDIR
host =
user =
sshoptions =
EOF

    chmod 0640 "${BATS_TMPDIR}/backup.d/test.rdiff"
}

finish_rdiff() {
    cleanup_backups local remote
}

@test "check ssh connection test" {
    setconfig testconnect yes
    setconfig dest type remote
    setconfig dest user $BN_REMOTEUSER
    setconfig dest host $BN_REMOTEHOST
    testaction
    greplog "Debug: Connected to ${BN_REMOTEHOST} as ${BN_REMOTEUSER} successfully$"
}

@test "check config parameter nicelevel" {
    # nicelevel is 0 by default
    delconfig nicelevel
    testaction
    greplog 'Debug: executing rdiff-backup$' '\bnice -n 0\b'

    # nicelevel is defined
    setconfig nicelevel 19
    testaction
    greplog 'Debug: executing rdiff-backup$' '\bnice -n 19\b'
}

@test "check config parameter ionicelevel" {
    # no ionice by default
    delconfig ionicelevel
    testaction
    not_greplog 'Debug: executing rdiff-backup$' '\bionice -c2\b'

    # acceptable value
    setconfig ionicelevel 7
    testaction
    greplog 'Debug: executing rdiff-backup$' '\bionice -c2 -n 7\b'

    # unacceptable value
    setconfig ionicelevel 10
    testaction
    greplog 'Fatal: The value of ionicelevel is expected to be either empty or an integer from 0 to 7. Got: 10$'
}

@test "check config parameter bwlimit" {
    # no limit by default
    delconfig bwlimit
    setconfig dest type remote
    setconfig dest user $BN_REMOTEUSER
    setconfig dest host $BN_REMOTEHOST
    testaction
    not_greplog 'Debug: executing rdiff-backup$' '\bcstream -t\b'

    # limit is defined
    setconfig bwlimit 1024000
    setconfig dest type remote
    setconfig dest user $BN_REMOTEUSER
    setconfig dest host $BN_REMOTEHOST
    testaction
    greplog 'Debug: executing rdiff-backup$' '\bcstream -t 1024000\b'
}

@test "check config parameter ignore_version" {
    # undefined, defaults to no
    delconfig ignore_version
    setconfig dest type remote
    setconfig dest user $BN_REMOTEUSER
    setconfig dest host $BN_REMOTEHOST
    testaction
    greplog 'Debug: executing rdiff-backup version checks$'
    greplog 'Debug: source version: rdiff-backup '
    greplog 'Debug: destination version: rdiff-backup '
    not_greplog 'Fatal: rdiff-backup does not have the same version at the source and at the destination.$'

    # defined, set to no
    setconfig ignore_version no
    setconfig dest type remote
    setconfig dest user $BN_REMOTEUSER
    setconfig dest host $BN_REMOTEHOST
    testaction
    greplog 'Debug: executing rdiff-backup version checks$'
    greplog 'Debug: source version: rdiff-backup '
    greplog 'Debug: destination version: rdiff-backup '
    not_greplog 'Fatal: rdiff-backup does not have the same version at the source and at the destination.$'

    # defined, set to yes
    setconfig ignore_version yes
    setconfig dest type remote
    setconfig dest user $BN_REMOTEUSER
    setconfig dest host $BN_REMOTEHOST
    testaction
    not_greplog 'Debug: executing rdiff-backup version checks$'
    not_greplog 'Debug: source version: rdiff-backup '
    not_greplog 'Debug: destination version: rdiff-backup '
    not_greplog 'Fatal: rdiff-backup does not have the same version at the source and at the destination.$'
}

@test "check config parameter options" {
    # undefined, default empty
    delconfig options
    testaction
    greplog 'Debug: executing rdiff-backup$' "\brdiff-backup\s\+--print-statistics\s"

    # defined, set to --tempdir /tmp
    setconfig options "--tempdir /tmp"
    testaction
    greplog 'Debug: executing rdiff-backup$' "\brdiff-backup\s\+--tempdir /tmp --print-statistics\s"
}

@test "check config parameter source/type" {
    # undefined, defaults empty
    delconfig source type
    testaction
    greplog "Fatal: sourcetype '' is neither local nor remote$"

    # defined, set to local
    setconfig source type local
    testaction
    not_greplog "Fatal: sourcetype '' is neither local nor remote$"
    greplog 'Debug: executing rdiff-backup$' "\s/ ${BN_BACKUPDIR}/testrdiff$"

    # defined, set to remote
    setconfig source type remote
    setconfig source user "$BN_REMOTEUSER"
    setconfig source host "$BN_REMOTEHOST"
    testaction
    not_greplog "Fatal: sourcetype '' is neither local nor remote$"
    greplog 'Debug: executing rdiff-backup$' "\s${BN_REMOTEUSER}@${BN_REMOTEHOST}::/ ${BN_BACKUPDIR}/testrdiff$"
}

@test "check config parameter source/label" {
    # undefined, defaults empty
    delconfig source label
    testaction
    greplog 'Debug: executing rdiff-backup$' "\s/ ${BN_BACKUPDIR}/$"

    # defined, set to testrdiff
    setconfig source label testrdiff
    testaction
    greplog 'Debug: executing rdiff-backup$' "\s/ ${BN_BACKUPDIR}/testrdiff$"
}

@test "check config parameters source/user and source/host" {
    # user undefined, type remote, defaults empty
    setconfig source type remote
    delconfig source user
    setconfig source host "$BN_REMOTEHOST"
    testaction
    greplog 'Fatal: User must be specified for remote source.'

    # host undefined, type remote, defaults empty
    setconfig source type remote
    setconfig source user "$BN_REMOTEUSER"
    delconfig source host
    testaction
    greplog 'Fatal: Host must be specified for remote source.'

    # user/host undefined, type local, defaults empty (noop)
    setconfig source type local
    delconfig source user
    delconfig source host
    testaction
    greplog 'Debug: executing rdiff-backup$' "\s/ ${BN_BACKUPDIR}/testrdiff$"

    # defined, type remote
    setconfig source type remote
    setconfig source user "$BN_REMOTEUSER"
    setconfig source host "$BN_REMOTEHOST"
    testaction
    greplog 'Debug: executing rdiff-backup$' "\s${BN_REMOTEUSER}@${BN_REMOTEHOST}::/ ${BN_BACKUPDIR}/testrdiff$"

    # defined, type local (noop)
    setconfig source type local
    setconfig source user "$BN_REMOTEUSER"
    setconfig source host "$BN_REMOTEHOST"
    testaction
    greplog 'Debug: executing rdiff-backup$' "\s/ ${BN_BACKUPDIR}/testrdiff$"
}

@test "check config parameter source/keep" {
    # undefined, defaults to 60
    delconfig source keep
    testaction
    greplog 'Debug: executing rdiff-backup --remove-older-than$' '\s--remove-older-than 60D\s'

    # defined, set to 180
    testaction
    setconfig source keep 180
    testaction
    greplog 'Debug: executing rdiff-backup --remove-older-than$' '\s--remove-older-than 180D\s'

    # defined, set to 6M
    testaction
    setconfig source keep 6M
    testaction
    greplog 'Debug: executing rdiff-backup --remove-older-than$' '\s--remove-older-than 6M\s'

    # defined, set to 1 year
    testaction
    setconfig source keep "1 year"
    testaction
    greplog 'Fatal: Keep parameter contains an invalid value (1 year).$'

    # defined, set to yes
    testaction
    setconfig source keep yes
    testaction
    not_greplog 'Fatal: Keep parameter contains an invalid value (yes).$'
    not_greplog 'Debug: executing rdiff-backup --remove-older-than$'
}

@test "check config parameter source/include" {
    # no includes, defaults source path to "/"
    delconfig source include
    delconfig source exclude
    testaction
    not_greplog 'Debug: executing rdiff-backup$' "\s--include"
    greplog 'Debug: executing rdiff-backup$' "\s--print-statistics / ${BN_BACKUPDIR}/testrdiff$"

    # single path, invalid
    setconfig source include /
    testaction
    greplog "Fatal: Sorry, you cannot use 'include = /'$"

    # single path
    setconfig source include "$BN_SRCDIR"
    testaction
    greplog 'Debug: executing rdiff-backup$' "\s--include '${BN_SRCDIR}' --exclude '/\*' /\s"

    # multiple paths
    setconfig_repeat backup.d/test.rdiff source include "$BN_SRCDIR" /foo /bar
    testaction
    greplog 'Debug: executing rdiff-backup$' "\s--include '${BN_SRCDIR}' --include '/foo' --include '/bar' --exclude '/\*' /\s"

    # regular path and filelist
    setconfig_repeat backup.d/test.rdiff source include "$BN_SRCDIR" "@/etc/backup-list.txt"
    testaction
    greplog 'Debug: executing rdiff-backup$' "\s--include '${BN_SRCDIR}' --include-globbing-filelist '/etc/backup-list.txt' --exclude '/\*' /\s"
}

@test "check config parameter source/exclude" {
    # no excludes, defaults source path to "/"
    delconfig source exclude
    testaction
    greplog 'Debug: executing rdiff-backup$' "\s--print-statistics --include '${BN_SRCDIR}' --exclude '/\*' / ${BN_BACKUPDIR}/testrdiff$"

    # single path
    setconfig source exclude "${BN_SRCDIR}/foo"
    testaction
    greplog 'Debug: executing rdiff-backup$' "\s--exclude '${BN_SRCDIR}/foo' --include '${BN_SRCDIR}' --exclude '/\*' /\s"

    # multiple paths
    setconfig_repeat backup.d/test.rdiff source exclude "${BN_SRCDIR}/foo" "${BN_SRCDIR}/bar"
    testaction
    greplog 'Debug: executing rdiff-backup$' "\s--exclude '${BN_SRCDIR}/foo' --exclude '${BN_SRCDIR}/bar' --include '${BN_SRCDIR}' --exclude '/\*' /\s"

    # regular path and filelist
    setconfig_repeat backup.d/test.rdiff source exclude "${BN_SRCDIR}/foo" "@/etc/backup-exlist.txt"
    testaction
    greplog 'Debug: executing rdiff-backup$' "\s--exclude '${BN_SRCDIR}/foo' --exclude-globbing-filelist '/etc/backup-exlist.txt' --include '${BN_SRCDIR}' --exclude '/\*' /\s"
}

@test "check config parameter dest/type" {
    # undefined, defaults empty
    delconfig dest type
    testaction
    greplog "Fatal: desttype '' is neither local nor remote$"

    # defined, set to local
    setconfig dest type local
    testaction
    greplog 'Debug: executing rdiff-backup$' "\s/ ${BN_BACKUPDIR}/testrdiff$"

    # defined, set to remote
    setconfig dest type remote
    setconfig dest user "$BN_REMOTEUSER"
    setconfig dest host "$BN_REMOTEHOST"
    testaction
    greplog 'Debug: executing rdiff-backup$' "\s/ ${BN_REMOTEUSER}@${BN_REMOTEHOST}::${BN_BACKUPDIR}/testrdiff$"
}

@test "check config parameters dest/user and dest/host" {
    # user undefined, type remote, defaults empty
    setconfig dest type remote
    delconfig dest user
    setconfig dest host "$BN_REMOTEHOST"
    testaction
    greplog 'Fatal: User must be specified for remote destination.'

    # host undefined, type remote, defaults empty
    setconfig dest type remote
    setconfig dest user "$BN_REMOTEUSER"
    delconfig dest host
    testaction
    greplog 'Fatal: Host must be specified for remote destination.'

    # user/host undefined, type local, defaults empty (noop)
    setconfig dest type local
    delconfig dest user
    delconfig dest host
    testaction
    greplog 'Debug: executing rdiff-backup$' "\s/ ${BN_BACKUPDIR}/testrdiff$"

    # defined, type remote
    setconfig dest type remote
    setconfig dest user "$BN_REMOTEUSER"
    setconfig dest host "$BN_REMOTEHOST"
    testaction
    greplog 'Debug: executing rdiff-backup$' "\s/ ${BN_REMOTEUSER}@${BN_REMOTEHOST}::${BN_BACKUPDIR}/testrdiff$"

    # defined, type local (noop)
    setconfig dest type local
    setconfig dest user "$BN_REMOTEUSER"
    setconfig dest host "$BN_REMOTEHOST"
    testaction
    greplog 'Debug: executing rdiff-backup$' "\s/ ${BN_BACKUPDIR}/testrdiff$"
}


@test "check config parameter dest/directory" {
    # undefined, defaults empty
    delconfig dest directory
    testaction
    greplog "Fatal: Destination directory not set$"

    # defined, type local
    setconfig dest type local
    setconfig dest directory "$BN_BACKUPDIR"
    testaction
    greplog 'Debug: executing rdiff-backup$' "\s/ ${BN_BACKUPDIR}/testrdiff$"

    # defined, type remote, set to $BN_BACKUPDIR
    setconfig dest type remote
    setconfig dest directory "$BN_BACKUPDIR"
    setconfig dest user "$BN_REMOTEUSER"
    setconfig dest host "$BN_REMOTEHOST"
    testaction
    greplog 'Debug: executing rdiff-backup$' "\s/ ${BN_REMOTEUSER}@${BN_REMOTEHOST}::${BN_BACKUPDIR}/testrdiff$"
}

@test "check config parameter dest/sshoptions" {
    # undefined, default empty
    delconfig dest sshoptions
    setconfig dest type remote
    setconfig dest directory "$BN_BACKUPDIR"
    setconfig dest user "$BN_REMOTEUSER"
    setconfig dest host "$BN_REMOTEHOST"
    testaction
    greplog 'Debug: executing rdiff-backup$' "\brdiff-backup\s\+--print-statistics\s"

    # defined, set to -4
    setconfig dest sshoptions "-o IdentityFile=/root/.ssh/id_ed25519"
    testaction
    greplog 'Debug: executing rdiff-backup$' "\brdiff-backup\s\+--remote-schema 'ssh -C -o IdentityFile=/root/.ssh/id_ed25519 %s rdiff-backup --server'\s"
}

@test "create local backup" {
    cleanup_backups local
    runaction
    greplog "Info: Successfully finished backing up source testrdiff$"
}

@test "verify local backup" {
    rm -f "${BATS_TMPDIR}/_rdiff-verify.log"
    rdiff-backup -v5 --verify "${BN_BACKUPDIR}/testrdiff" > "${BATS_TMPDIR}/_rdiff-verify.log"
}

@test "verify number of files in local backup matches source" {
    SRC_FILES="$(find "${BN_SRCDIR}" -type f -not -path "${BN_SRCDIR}/var/*" | wc -l)"
    BACKUP_FILES="$(grep -c 'Verified SHA1 digest of' "${BATS_TMPDIR}/_rdiff-verify.log")"
    [ "$SRC_FILES" -eq "$BACKUP_FILES" ]
}

@test "create remote backup" {
    cleanup_backups remote
    setconfig dest type remote
    setconfig dest host "$BN_REMOTEHOST"
    setconfig dest user "$BN_REMOTEUSER"
    runaction
    greplog "Info: Successfully finished backing up source testrdiff$"
}

@test "verify remote backup" {
    rm -f "${BATS_TMPDIR}/_rdiff-verify.log"
    ssh "${BN_REMOTEUSER}@${BN_REMOTEHOST}" -- rdiff-backup -v5 --verify "${BN_BACKUPDIR}/testrdiff" > "${BATS_TMPDIR}/_rdiff-verify.log"
}

@test "verify number of files in remote backup matches source" {
    SRC_FILES="$(find "${BN_SRCDIR}" -type f -not -path "${BN_SRCDIR}/var/*" | wc -l)"
    BACKUP_FILES="$(grep -c 'Verified SHA1 digest of' "${BATS_TMPDIR}/_rdiff-verify.log")"
    echo "$SRC_FILES $BACKUP_FILES"
    [ "$SRC_FILES" -eq "$BACKUP_FILES" ]
}


