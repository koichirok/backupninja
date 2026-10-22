load common

setup_gitlab() {
    mkdir -p "${BATS_TEST_TMPDIR}/bin" "${BN_BACKUPDIR}/gitlab-target"
    export PATH="${BATS_TEST_TMPDIR}/bin:$PATH"
    export GITLAB_TEST_ROOT="${BATS_TEST_TMPDIR}"
    export GITLAB_TEST_BACKUPS="${BN_BACKUPDIR}/gitlab-target"
    cat > "${BATS_TEST_TMPDIR}/bin/gitlab-backup" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" > "$GITLAB_TEST_ROOT/args"
env | grep '^GITLAB_BACKUP_PG' > "$GITLAB_TEST_ROOT/environment"
if [ -n "$GITLAB_TEST_FAIL" ]; then
    echo partial > "$GITLAB_TEST_BACKUPS/archive.tar"
    exit 1
fi
echo archive > "$GITLAB_TEST_BACKUPS/archive.tar"
EOF
    chmod +x "${BATS_TEST_TMPDIR}/bin/gitlab-backup"
    cat > "${BATS_TMPDIR}/backup.d/test.gitlab" <<EOF
backupdir = ${GITLAB_TEST_BACKUPS}
EOF
    chmod 0640 "${BATS_TMPDIR}/backup.d/test.gitlab"
}

teardown_gitlab() {
    cleanup_backups local
}

@test "runs GitLab backups locally with default cron suppression" {
    runaction
    [ "$status" -eq 0 ]
    greplog "Info: Successfully finished GitLab backup"
    [ "$(cat "${BATS_TEST_TMPDIR}/args")" = $'create\nCRON=1' ]
    [ "$(cat "${GITLAB_TEST_BACKUPS}/archive.tar")" = archive ]
}

@test "maps options and repeated exclusions without splitting arguments" {
    setconfig cron no
    setconfig trace yes
    setconfig strategy copy
    setconfig filename "daily backup"
    setconfig gzip_rsyncable yes
    setconfig_repeat '' skip artifacts registry
    setconfig skip_tar yes
    setconfig max_concurrency 2
    setconfig max_storage_concurrency 1
    setconfig remote_directory daily
    runaction
    [ "$status" -eq 0 ]
    for arg in --trace STRATEGY=copy 'BACKUP=daily backup' GZIP_RSYNCABLE=yes \
        SKIP=artifacts,registry,tar GITLAB_BACKUP_MAX_CONCURRENCY=2 \
        GITLAB_BACKUP_MAX_STORAGE_CONCURRENCY=1 DIRECTORY=daily; do
        grep -Fxq -- "$arg" "${BATS_TEST_TMPDIR}/args"
    done
    run grep -Fx CRON=1 "${BATS_TEST_TMPDIR}/args"
    [ "$status" -eq 1 ]
}

@test "passes database overrides without logging credentials" {
    for pair in 'pghost db' 'pguser gitlab' 'pgport 5432' 'pgpassword test-secret' \
        'pgsslmode verify-full' 'pgsslkey /key' 'pgsslcert /cert' \
        'pgsslrootcert /rootcert' 'pgsslcrl /crl' 'pgsslcompression 0'; do
        setconfig ${pair}
    done
    runaction
    [ "$status" -eq 0 ]
    grep -Fxq 'GITLAB_BACKUP_PGPASSWORD=test-secret' "${BATS_TEST_TMPDIR}/environment"
    grep -Fxq 'GITLAB_BACKUP_PGSSLCOMPRESSION=0' "${BATS_TEST_TMPDIR}/environment"
    [ "$(wc -l < "${BATS_TEST_TMPDIR}/environment")" -eq 10 ]
    not_greplog test-secret
    [[ "$output" != *test-secret* ]]
}

@test "container backup is fetched only on success" {
    mock_container_runtime
    setconfig transport transport podman
    setconfig transport container gitlab
    setconfig transport hostbackupdir "${BN_BACKUPDIR}/gitlab-host"
    runaction
    [ "$status" -eq 0 ]
    [ "$(cat "${BN_BACKUPDIR}/gitlab-host/archive.tar")" = archive ]
    grep -Fxq "exec -i gitlab tar -cf - -C ${GITLAB_TEST_BACKUPS} ." "${BATS_TEST_TMPDIR}/runtime.log"
}

@test "failed backup reports an error and preserves previous host files" {
    mock_container_runtime
    export GITLAB_TEST_FAIL=1
    setconfig transport transport podman
    setconfig transport container gitlab
    setconfig transport hostbackupdir "${BN_BACKUPDIR}/gitlab-host"
    mkdir -p "${BN_BACKUPDIR}/gitlab-host"
    echo previous > "${BN_BACKUPDIR}/gitlab-host/archive.tar"
    runaction
    [ "$status" -ne 0 ]
    greplog "Error: Failed to create GitLab backup"
    [ "$(cat "${BN_BACKUPDIR}/gitlab-host/archive.tar")" = previous ]
    run grep ' tar ' "${BATS_TEST_TMPDIR}/runtime.log"
    [ "$status" -eq 1 ]
}

@test "failed transfer reports a fatal error and preserves host files" {
    mock_container_runtime
    setconfig transport transport podman
    setconfig transport container gitlab
    setconfig transport hostbackupdir "${BN_BACKUPDIR}/gitlab-host"
    setconfig backupdir "${BN_BACKUPDIR}/missing-gitlab"
    mkdir -p "${BN_BACKUPDIR}/gitlab-host"
    echo previous > "${BN_BACKUPDIR}/gitlab-host/archive.tar"
    runaction
    [ "$status" -ne 0 ]
    greplog "Fatal: Failed to fetch"
    [ "$(cat "${BN_BACKUPDIR}/gitlab-host/archive.tar")" = previous ]
}

@test "test mode neither creates nor fetches backups" {
    mock_container_runtime
    setconfig transport transport podman
    setconfig transport container gitlab
    setconfig transport hostbackupdir "${BN_BACKUPDIR}/gitlab-host"
    testaction
    [ "$status" -eq 0 ]
    [ ! -e "${BATS_TEST_TMPDIR}/args" ]
    [ ! -e "${BN_BACKUPDIR}/gitlab-host" ]
}

@test "rejects an unsupported strategy" {
    setconfig strategy unsupported
    runaction
    [ "$status" -ne 0 ]
    greplog "Fatal: Unsupported GitLab backup strategy"
}
