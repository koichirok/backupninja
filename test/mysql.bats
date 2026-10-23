load common

begin_mysql() {
    install_pkgs default-mysql-server
    systemctl is-active mysql || systemctl start mysql
    zcat "${BATS_TEST_DIRNAME}/samples/bntest_p8Cz8k.sql.gz" | mysql --defaults-file=/etc/mysql/debian.cnf
    zcat "${BATS_TEST_DIRNAME}/samples/bntest_v11vJj.sql.gz" | mysql --defaults-file=/etc/mysql/debian.cnf
}

setup_mysql() {
    cat << EOF > "${BATS_TMPDIR}/backup.d/test.mysql"
databases = all
backupdir = ${BN_BACKUPDIR}/mysql
hotcopy = no
sqldump = yes
compress = yes
EOF

    chmod 0640 "${BATS_TMPDIR}/backup.d/test.mysql"
}

finish_mysql() {
    mysqladmin -f drop bntest_p8Cz8k
    mysqladmin -f drop bntest_v11vJj
    systemctl stop mysql
}

teardown_mysql() {
    cleanup_backups local
}

@test "sqldump: exports all databases, with compression" {
    setconfig databases all
    setconfig compress yes
    runaction
    [ -s "${BN_BACKUPDIR}/mysql/sqldump/bntest_p8Cz8k.sql.gz" ]
    [ -s "${BN_BACKUPDIR}/mysql/sqldump/bntest_v11vJj.sql.gz" ]
    [ "$(zgrep -c 'INSERT INTO' ${BN_BACKUPDIR}/mysql/sqldump/bntest_p8Cz8k.sql.gz)" -eq 9 ]
    [ "$(zgrep -c 'INSERT INTO' ${BN_BACKUPDIR}/mysql/sqldump/bntest_v11vJj.sql.gz)" -eq 47 ]
}

@test "sqldump: exports all databases, without compression" {
    setconfig databases all
    setconfig compress no
    runaction
    [ -s "${BN_BACKUPDIR}/mysql/sqldump/bntest_p8Cz8k.sql" ]
    [ -s "${BN_BACKUPDIR}/mysql/sqldump/bntest_v11vJj.sql" ]
    [ "$(grep -c 'INSERT INTO' ${BN_BACKUPDIR}/mysql/sqldump/bntest_p8Cz8k.sql)" -eq 9 ]
    [ "$(grep -c 'INSERT INTO' ${BN_BACKUPDIR}/mysql/sqldump/bntest_v11vJj.sql)" -eq 47 ]
}

@test "sqldump: exports specific database" {
    setconfig databases bntest_v11vJj
    runaction
    [ ! -f ${BN_BACKUPDIR}/mysql/sqldump/bntest_p8Cz8k.sql.gz ]
    [ -s "${BN_BACKUPDIR}/mysql/sqldump/bntest_v11vJj.sql.gz" ]
    [ "$(zgrep -c 'INSERT INTO' ${BN_BACKUPDIR}/mysql/sqldump/bntest_v11vJj.sql.gz)" -eq 47 ]
}

@test "ignores: exports all databases while excluding two tables entirely" {
    setconfig databases all
    setconfig ignores "bntest_v11vJj.cache_data bntest_v11vJj.cache_entity"
    runaction
    [ -s "${BN_BACKUPDIR}/mysql/sqldump/bntest_p8Cz8k.sql.gz" ]
    [ "$(zgrep -c 'INSERT INTO' ${BN_BACKUPDIR}/mysql/sqldump/bntest_p8Cz8k.sql.gz)" -eq 9 ]
    [ -s "${BN_BACKUPDIR}/mysql/sqldump/bntest_v11vJj.sql.gz" ]
    [ "$(zgrep -c 'CREATE TABLE `cache_data`' ${BN_BACKUPDIR}/mysql/sqldump/bntest_v11vJj.sql.gz)" -eq 0 ]
    [ "$(zgrep -c 'CREATE TABLE `cache_entity`' ${BN_BACKUPDIR}/mysql/sqldump/bntest_v11vJj.sql.gz)" -eq 0 ]
    [ "$(zgrep -c 'CREATE TABLE' ${BN_BACKUPDIR}/mysql/sqldump/bntest_v11vJj.sql.gz)" -eq 66 ]
}

@test "nodata: exports all databases while excluding data from one table, with compression" {
    setconfig databases all
    setconfig compress yes
    setconfig nodata bntest_v11vJj.cache_data
    runaction
    [ -s "${BN_BACKUPDIR}/mysql/sqldump/bntest_p8Cz8k.sql.gz" ]
    [ "$(zgrep -c 'INSERT INTO' ${BN_BACKUPDIR}/mysql/sqldump/bntest_p8Cz8k.sql.gz)" -eq 9 ]
    [ -s "${BN_BACKUPDIR}/mysql/sqldump/bntest_v11vJj.sql.gz" ]
    [ "$(zgrep -c 'INSERT INTO `cache_data`' ${BN_BACKUPDIR}/mysql/sqldump/bntest_v11vJj.sql.gz)" -eq 0 ]
    [ "$(zgrep -c 'CREATE TABLE' ${BN_BACKUPDIR}/mysql/sqldump/bntest_v11vJj.sql.gz)" -eq 68 ]
}

@test "nodata: exports all databases while excluding data from one table, without compression" {
    setconfig databases all
    setconfig compress no
    setconfig nodata bntest_v11vJj.cache_data
    runaction
    [ -s "${BN_BACKUPDIR}/mysql/sqldump/bntest_p8Cz8k.sql" ]
    [ "$(grep -c 'INSERT INTO' ${BN_BACKUPDIR}/mysql/sqldump/bntest_p8Cz8k.sql)" -eq 9 ]
    [ -s "${BN_BACKUPDIR}/mysql/sqldump/bntest_v11vJj.sql" ]
    [ "$(grep -c 'INSERT INTO `cache_data`' ${BN_BACKUPDIR}/mysql/sqldump/bntest_v11vJj.sql)" -eq 0 ]
    [ "$(grep -c 'CREATE TABLE' ${BN_BACKUPDIR}/mysql/sqldump/bntest_v11vJj.sql)" -eq 68 ]
}

@test "nodata: exports all databases while excluding data from two tables, with compression" {
    setconfig databases all
    setconfig compress yes
    setconfig nodata "bntest_v11vJj.cache_data bntest_v11vJj.cache_entity"
    runaction
    [ -s "${BN_BACKUPDIR}/mysql/sqldump/bntest_p8Cz8k.sql.gz" ]
    [ "$(zgrep -c 'INSERT INTO' ${BN_BACKUPDIR}/mysql/sqldump/bntest_p8Cz8k.sql.gz)" -eq 9 ]
    [ -s "${BN_BACKUPDIR}/mysql/sqldump/bntest_v11vJj.sql.gz" ]
    [ "$(zgrep -c 'INSERT INTO `cache_data`' ${BN_BACKUPDIR}/mysql/sqldump/bntest_v11vJj.sql.gz)" -eq 0 ]
    [ "$(zgrep -c 'INSERT INTO `cache_entity`' ${BN_BACKUPDIR}/mysql/sqldump/bntest_v11vJj.sql.gz)" -eq 0 ]
    [ "$(zgrep -c 'CREATE TABLE' ${BN_BACKUPDIR}/mysql/sqldump/bntest_v11vJj.sql.gz)" -eq 68 ]
}

@test "nodata: exports all databases while excluding data from two tables, without compression" {
    setconfig databases all
    setconfig compress no
    setconfig nodata "bntest_v11vJj.cache_data bntest_v11vJj.cache_entity"
    runaction
    [ -s "${BN_BACKUPDIR}/mysql/sqldump/bntest_p8Cz8k.sql" ]
    [ "$(grep -c 'INSERT INTO' ${BN_BACKUPDIR}/mysql/sqldump/bntest_p8Cz8k.sql)" -eq 9 ]
    [ -s "${BN_BACKUPDIR}/mysql/sqldump/bntest_v11vJj.sql" ]
    [ "$(grep -c 'INSERT INTO `cache_data`' ${BN_BACKUPDIR}/mysql/sqldump/bntest_v11vJj.sql)" -eq 0 ]
    [ "$(grep -c 'INSERT INTO `cache_entity`' ${BN_BACKUPDIR}/mysql/sqldump/bntest_v11vJj.sql)" -eq 0 ]
    [ "$(grep -c 'CREATE TABLE' ${BN_BACKUPDIR}/mysql/sqldump/bntest_v11vJj.sql)" -eq 68 ]
}

@test "hotcopy: exports all databases" {
    skip "not implemented, requires MyISAM tables, method is deprecated upstream"
}

@test "hotcopy: exports specific databases" {
    skip "not implemented, requires MyISAM tables, method is deprecated upstream"
}

@test "transport: dumps through a container runtime and fetches to the host" {
    mock_container_runtime
    setconfig databases bntest_v11vJj
    setconfig compress yes
    setconfig backupdir "${BN_BACKUPDIR}/mysql-container"
    setconfig transport transport podman
    setconfig transport container bntest-mysql
    setconfig transport hostbackupdir "${BN_BACKUPDIR}/mysql-host"
    runaction
    greplog "Info: Successfully finished dump of mysql database bntest_v11vJj"
    not_greplog "Warning:"
    [ "$(zgrep -c 'INSERT INTO' "${BN_BACKUPDIR}/mysql-host/sqldump/bntest_v11vJj.sql.gz")" -eq 47 ]
    grep -q '^exec -i bntest-mysql sh -c ' "${BATS_TEST_TMPDIR}/runtime.log"
    grep -Fxq "exec -i bntest-mysql tar -cf - -C ${BN_BACKUPDIR}/mysql-container ." \
        "${BATS_TEST_TMPDIR}/runtime.log"
}

@test "transport: failed dump does not replace the host backup" {
    mock_container_runtime
    setconfig databases bntest_doesnotexist
    setconfig compress no
    setconfig backupdir "${BN_BACKUPDIR}/mysql-container"
    setconfig transport transport podman
    setconfig transport container bntest-mysql
    setconfig transport hostbackupdir "${BN_BACKUPDIR}/mysql-host-fail"
    mkdir -p "${BN_BACKUPDIR}/mysql-host-fail"
    echo previous > "${BN_BACKUPDIR}/mysql-host-fail/marker"
    runaction
    greplog "Error: Failed to dump mysql databases bntest_doesnotexist"
    greplog "Error: Not fetching backups"
    run grep -q ' tar ' "${BATS_TEST_TMPDIR}/runtime.log"
    [ "$status" -ne 0 ]
    [ "$(ls -A "${BN_BACKUPDIR}/mysql-host-fail")" = marker ]
}
