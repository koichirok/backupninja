load common

begin_tar() {
    install_pkgs ncompress zstd
    if [ ! -d "$BN_SRCDIR" ]; then
        make_rootfs testing "$BN_SRCDIR"
    fi
}

setup_tar() {
    cat << EOF > "${BATS_TMPDIR}/backup.d/test.tar"
when = manual
backupname = bntest
backupdir = ${BN_BACKUPDIR}/tartest
compress = none
includes = $BN_SRCDIR
excludes = ${BN_SRCDIR}/var
EOF

    chmod 0640 "${BATS_TMPDIR}/backup.d/test.tar"
}

teardown_tar() {
    cleanup_backups local
}

@test "no compression" {
    runaction
    greplog "Info: FINISHED: 1 actions run. 0 fatal. 0 error. 0 warning."
    archive=$(find "${BN_BACKUPDIR}/tartest" -maxdepth 1 -name bntest-\*.tar)
    [ -s "$archive" ]
    tar xOf "$archive" &> /dev/null
}

@test "compress compression" {
    setconfig compress compress
    runaction
    greplog "Info: FINISHED: 1 actions run. 0 fatal. 0 error. 0 warning."
    archive=$(find "${BN_BACKUPDIR}/tartest" -maxdepth 1 -name bntest-\*.tar.compress)
    [ -s "$archive" ]
    tar xZOf "$archive" &> /dev/null
}

@test "gzip compression" {
    setconfig compress gzip
    runaction
    greplog "Info: FINISHED: 1 actions run. 0 fatal. 0 error. 0 warning."
    archive=$(find "${BN_BACKUPDIR}/tartest" -maxdepth 1 -name bntest-\*.tgz)
    [ -s "$archive" ]
    tar xzOf "$archive" &> /dev/null
}

@test "bzip2 compression" {
    setconfig compress bzip
    runaction
    greplog "Info: FINISHED: 1 actions run. 0 fatal. 0 error. 0 warning."
    archive=$(find "${BN_BACKUPDIR}/tartest" -maxdepth 1 -name bntest-\*.tar.bz2)
    [ -s "$archive" ]
    tar xjOf "$archive" &> /dev/null
}

@test "xz compression" {
    setconfig compress xz
    runaction
    greplog "Info: FINISHED: 1 actions run. 0 fatal. 0 error. 0 warning."
    archive=$(find "${BN_BACKUPDIR}/tartest" -maxdepth 1 -name bntest-\*.tar.xz)
    [ -s "$archive" ]
    tar xJOf "$archive" &> /dev/null
}

@test "zstd compression" {
    setconfig compress zstd
    runaction
    greplog "Info: FINISHED: 1 actions run. 0 fatal. 0 error. 0 warning."
    archive=$(find "${BN_BACKUPDIR}/tartest" -maxdepth 1 -name bntest-\*.tar.zst)
    [ -s "$archive" ]
    tar --zstd -xOf "$archive" &> /dev/null
}

@test "unknown compression, defaults to gzip" {
    setconfig compress foo
    runaction
    greplog "Info: FINISHED: 1 actions run. 0 fatal. 0 error. 1 warning."
    archive=$(find "${BN_BACKUPDIR}/tartest" -maxdepth 1 -name bntest-\*.tgz)
    [ -s "$archive" ]
    tar xzOf "$archive" &> /dev/null
}
