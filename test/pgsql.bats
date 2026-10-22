load common

begin_pgsql() {
    install_pkgs postgresql
    systemctl is-active postgresql || systemctl start postgresql
    sudo -u postgres createuser --superuser root
    createdb bntest_p8Cz8k
    createdb bntest_v11vJj
    zcat "${BATS_TEST_DIRNAME}/samples/bntest_p8Cz8k.psql.gz" | psql -d bntest_p8Cz8k
    zcat "${BATS_TEST_DIRNAME}/samples/bntest_v11vJj.psql.gz" | psql -d bntest_v11vJj
}

setup_pgsql() {
    cat << EOF > "${BATS_TMPDIR}/backup.d/test.pgsql"
databases = all
backupdir = ${BN_BACKUPDIR}/postgres
compress = yes
format = plain
EOF

    chmod 0640 "${BATS_TMPDIR}/backup.d/test.pgsql"
}

finish_pgsql() {
    dropdb bntest_p8Cz8k
    dropdb bntest_v11vJj
    sudo -u postgres dropuser root
    systemctl stop postgresql
}

teardown_pgsql() {
    cleanup_backups local
}

@test "plain: exports all databases, with compression" {
    setconfig databases all
    setconfig compress yes
    setconfig format plain
    runaction
    gzip -tq "${BN_BACKUPDIR}/postgres/bntest0-all.sql.gz"
}

@test "plain: exports all databases, without compression" {
    setconfig databases all
    setconfig compress no
    setconfig format plain
    runaction
    [ -s "${BN_BACKUPDIR}/postgres/bntest0-all.sql" ]
}

@test "plain: exports specific database, with compression" {
    setconfig databases bntest_v11vJj
    setconfig compress yes
    setconfig format plain
    runaction
    gzip -tq "${BN_BACKUPDIR}/postgres/bntest_v11vJj.sql.gz"
    [ "$(zgrep -c -e '^COPY' ${BN_BACKUPDIR}/postgres/bntest_v11vJj.sql.gz)" -eq 68 ]
    [ ! -e "${BN_BACKUPDIR}/postgres/bntest_p8Cz8k.sql.gz" ]
}

@test "plain: exports specific database, without compression" {
    setconfig databases bntest_v11vJj
    setconfig compress no
    setconfig format plain
    runaction
    [ -s "${BN_BACKUPDIR}/postgres/bntest_v11vJj.sql" ]
    [ "$(grep -c -e '^COPY' ${BN_BACKUPDIR}/postgres/bntest_v11vJj.sql)" -eq 68 ]
    [ ! -e "${BN_BACKUPDIR}/postgres/bntest_p8Cz8k.sql" ]
}

@test "tar: exports all databases, with compression" {
    setconfig databases all
    setconfig compress yes
    setconfig format tar
    runaction
    gzip -tq "${BN_BACKUPDIR}/postgres/bntest_p8Cz8k.pg_dump.gz"
    gzip -tq "${BN_BACKUPDIR}/postgres/bntest_v11vJj.pg_dump.gz"
    gzip -tq "${BN_BACKUPDIR}/postgres/globals.sql.gz"
}

@test "tar: exports all databases, without compression" {
    setconfig databases all
    setconfig compress no
    setconfig format tar
    runaction
    [ -s "${BN_BACKUPDIR}/postgres/bntest_p8Cz8k.pg_dump" ]
    [ -s "${BN_BACKUPDIR}/postgres/bntest_v11vJj.pg_dump" ]
    file ${BN_BACKUPDIR}/postgres/bntest_p8Cz8k.pg_dump | grep "POSIX tar archive"
    file ${BN_BACKUPDIR}/postgres/bntest_v11vJj.pg_dump | grep "POSIX tar archive"
    [ -s "${BN_BACKUPDIR}/postgres/globals.sql" ]
}

@test "tar: exports specific database, with compression" {
    setconfig databases bntest_v11vJj
    setconfig compress yes
    setconfig format tar
    runaction
    gzip -tq "${BN_BACKUPDIR}/postgres/bntest_v11vJj.pg_dump.gz"
    [ ! -e "${BN_BACKUPDIR}/postgres/bntest_p8Cz8k.pg_dump.gz" ]
    [ ! -e "${BN_BACKUPDIR}/postgres/globals.sql.gz" ]
}

@test "tar: exports specific database, without compression" {
    setconfig databases bntest_v11vJj
    setconfig compress no
    setconfig format tar
    runaction
    [ -s "${BN_BACKUPDIR}/postgres/bntest_v11vJj.pg_dump" ]
    file ${BN_BACKUPDIR}/postgres/bntest_v11vJj.pg_dump | grep -q "POSIX tar archive"
    [ ! -e "${BN_BACKUPDIR}/postgres/bntest_p8Cz8k.pg_dump" ]
    [ ! -e "${BN_BACKUPDIR}/postgres/globals.sql" ]
}

@test "custom: exports all databases, with compression" {
    setconfig databases all
    setconfig compress yes
    setconfig format custom
    runaction
    gzip -tq "${BN_BACKUPDIR}/postgres/bntest_p8Cz8k.pg_dump.gz"
    gzip -tq "${BN_BACKUPDIR}/postgres/bntest_v11vJj.pg_dump.gz"
    gzip -tq "${BN_BACKUPDIR}/postgres/globals.sql.gz"
}

@test "custom: exports all databases, without compression" {
    setconfig databases all
    setconfig compress no
    setconfig format custom
    runaction
    [ -s "${BN_BACKUPDIR}/postgres/bntest_p8Cz8k.pg_dump" ]
    [ -s "${BN_BACKUPDIR}/postgres/bntest_v11vJj.pg_dump" ]
    file "${BN_BACKUPDIR}/postgres/bntest_p8Cz8k.pg_dump" | grep -q "PostgreSQL custom database dump"
    file "${BN_BACKUPDIR}/postgres/bntest_v11vJj.pg_dump" | grep -q "PostgreSQL custom database dump"
    [ -s "${BN_BACKUPDIR}/postgres/globals.sql" ]
}

@test "custom: exports specific database, with compression" {
    setconfig databases bntest_v11vJj
    setconfig compress yes
    setconfig format custom
    runaction
    gzip -tq "${BN_BACKUPDIR}/postgres/bntest_v11vJj.pg_dump.gz"
    [ ! -e "${BN_BACKUPDIR}/postgres/bntest_p8Cz8k.pg_dump.gz" ]
    [ ! -e "${BN_BACKUPDIR}/postgres/globals.sql.gz" ]
}

@test "custom: exports specific database, without compression" {
    setconfig databases bntest_v11vJj
    setconfig compress no
    setconfig format custom
    runaction
    [ -s "${BN_BACKUPDIR}/postgres/bntest_v11vJj.pg_dump" ]
    file "${BN_BACKUPDIR}/postgres/bntest_v11vJj.pg_dump" | grep -q "PostgreSQL custom database dump"
    [ ! -e "${BN_BACKUPDIR}/postgres/bntest_p8Cz8k.pg_dump" ]
    [ ! -e "${BN_BACKUPDIR}/postgres/globals.sql" ]
}


@test "transport: dumps through a container runtime and fetches to the host" {
    mock_container_runtime
    setconfig databases bntest_v11vJj
    setconfig compress yes
    setconfig format plain
    setconfig backupdir "${BN_BACKUPDIR}/postgres-container"
    setconfig transport transport podman
    setconfig transport container bntest-postgres
    setconfig transport hostbackupdir "${BN_BACKUPDIR}/postgres-host"
    runaction
    greplog "Info: Successfully finished dump of pgsql database bntest_v11vJj"
    not_greplog "Warning:"
    gzip -tq "${BN_BACKUPDIR}/postgres-host/bntest_v11vJj.sql.gz"
    grep -q '^exec -i bntest-postgres sh -c su - postgres ' "${BATS_TEST_TMPDIR}/runtime.log"
    grep -Fxq "cp bntest-postgres:${BN_BACKUPDIR}/postgres-container/. ${BN_BACKUPDIR}/postgres-host/" \
        "${BATS_TEST_TMPDIR}/runtime.log"
}
