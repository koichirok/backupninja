load common

begin_rsync() {
    install_pkgs rsync
    if [ ! -d "$BN_SRCDIR" ]; then
        make_rootfs testing "$BN_SRCDIR"
    fi
}

setup_rsync() {
    cat << EOF > "${BATS_TMPDIR}/backup.d/test.rsync"
when = manual

[general]
log = ${BATS_TMPDIR}/log/rsync.log
mountpoint = $BN_BACKUPDIR
backupdir = testrsync
format = 

[source]
from = local
include = $BN_SRCDIR
exclude = var

[dest]
dest = local
host =
user =
id_file = /root/.ssh/id_ed25519
EOF

    chmod 0640 "${BATS_TMPDIR}/backup.d/test.rsync"
}

finish_rsync() {
    cleanup_backups local remote
}

@test "create local backup, short format" {
    cleanup_backups local
    setconfig general format short
    mkdir -p "${BN_BACKUPDIR}/testrsync"
    runaction
    greplog "Debug: Rsync transfer of $BN_SRCDIR finished successfully.$"
}

@test "verify local backup, short format" {
    run rsync -ain --exclude var --delete "${BN_SRCDIR}/" "${BN_BACKUPDIR}/testrsync${BN_SRCDIR}/bntest.0/"
    [ "$status" -eq 0 ]
    [ "$output" == ".d..t...... ./" ]
}

@test "verify local backup rotation, short format" {
    skip "not implemented"
}

@test "create local backup, long format" {
    cleanup_backups local
    setconfig general format long
    mkdir -p "${BN_BACKUPDIR}/testrsync"
    runaction
    greplog "Debug: Rsync transfer of $BN_SRCDIR finished successfully.$"
}

@test "verify local backup, long format" {
    run rsync -ain --exclude var --delete "${BN_SRCDIR}/" "${BN_BACKUPDIR}/testrsync${BN_SRCDIR}/daily.1/"
    [ "$status" -eq 0 ]
    [ "$output" == ".d..t...... ./" ]
}

@test "verify local backup rotation, long format" {
    skip "not implemented"
}

@test "create local backup, mirror format" {
    cleanup_backups local
    setconfig general format mirror
    mkdir -p "${BN_BACKUPDIR}/testrsync"
    runaction
    greplog "Debug: Rsync transfer of $BN_SRCDIR finished successfully.$"
}

@test "verify local backup, mirror format" {
    run rsync -ain --exclude var --delete "${BN_SRCDIR}/" "${BN_BACKUPDIR}/testrsync${BN_SRCDIR}/"
    [ "$status" -eq 0 ]
    [ "$output" == ".d..t...... ./" ]
}

@test "create remote backup, short format" {
    cleanup_backups remote
    setconfig general format short
    setconfig dest dest remote
    setconfig dest host "$BN_REMOTEHOST"
    setconfig dest user "$BN_REMOTEUSER"
    remote_command "mkdir -p \"${BN_BACKUPDIR}/testrsync\""
    runaction
    greplog "Debug: Rsync transfer of $BN_SRCDIR finished successfully.$"
}

@test "verify remote backup, short format" {
    run rsync -ain --exclude var --delete "${BN_SRCDIR}/" "${BN_REMOTEUSER}@${BN_REMOTEHOST}:${BN_BACKUPDIR}/testrsync${BN_SRCDIR}/bntest.0"
    [ "$status" -eq 0 ]
    if [ -n "$output" ]; then
        [ -z "$(printf '%s\n' "$output" | grep -v '^skipping non-regular file')" ]
    fi
}

@test "verify remote backup rotation, short format" {
    skip "not implemented"
}

@test "create remote backup, long format" {
    cleanup_backups remote
    setconfig general format long
    setconfig dest dest remote
    setconfig dest host "$BN_REMOTEHOST"
    setconfig dest user "$BN_REMOTEUSER"
    remote_command "mkdir -p \"${BN_BACKUPDIR}/testrsync\""
    runaction
    greplog "Debug: Rsync transfer of $BN_SRCDIR finished successfully.$"
}

@test "verify remote backup, long format" {
    run rsync -ain --exclude var --delete "${BN_SRCDIR}/" "${BN_REMOTEUSER}@${BN_REMOTEHOST}:${BN_BACKUPDIR}/testrsync${BN_SRCDIR}/daily.1"
    [ "$status" -eq 0 ]
    if [ -n "$output" ]; then
        [ -z "$(printf '%s\n' "$output" | grep -v '^skipping non-regular file')" ]
    fi
}

@test "verify remote backup rotation, long format" {
    skip "not implemented"
}

@test "create remote backup, mirror format" {
    cleanup_backups remote
    setconfig general format mirror
    setconfig dest dest remote
    setconfig dest host "$BN_REMOTEHOST"
    setconfig dest user "$BN_REMOTEUSER"
    remote_command "mkdir -p \"${BN_BACKUPDIR}/testrsync\""
    runaction
    greplog "Debug: Rsync transfer of $BN_SRCDIR finished successfully.$"
}

@test "verify remote backup, mirror format" {
    run rsync -ain --exclude var --delete "${BN_SRCDIR}/" "${BN_REMOTEUSER}@${BN_REMOTEHOST}:${BN_BACKUPDIR}/testrsync${BN_SRCDIR}/"
    [ "$status" -eq 0 ]
    if [ -n "$output" ]; then
        [ -z "$(printf '%s\n' "$output" | grep -v '^skipping non-regular file')" ]
    fi
}

