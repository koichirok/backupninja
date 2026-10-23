# Handler variables are consumed by the dynamically sourced scripts.
# shellcheck disable=SC2034
setup() {
    root="$BATS_TEST_TMPDIR"
    libdirectory="$BATS_TEST_DIRNAME/../lib"
    . "$libdirectory/tools"
    setfile "$root/action.conf"
    setsection ""
    debug() { printf 'Debug: %s\n' "$*"; }
    info() { printf 'Info: %s\n' "$*"; }
    warning() { printf 'Warning: %s\n' "$*" >&2; }
    error() { printf 'Error: %s\n' "$*" >&2; }
    fatal() { printf 'Fatal: %s\n' "$*" >&2; exit 2; }
    mkdir -p "$root/hostbin" "$root/targetbin" "$root/work dir" "$root/home" "$root/tmp"
    export AUDIT_ROOT="$root"
    export PATH="$root/hostbin:$PATH"
    export MOCK_UID=1001
    MYSQL=/target-only/mysql
    MYSQLADMIN=/target-only/mysqladmin
    MYSQLDUMP=/target-only/mysqldump
    MYSQLHOTCOPY=/target-only/mysqlhotcopy
    PGSQLDUMP=/target-only/pg_dump
    PGSQLDUMPALL=/target-only/pg_dumpall
    PSQL=/target-only/psql
    PGSQLUSER=dbos
    GZIP=/bin/gzip
    GZIP_OPTS=-n
    cat > "$root/hostbin/runtime" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >> "$AUDIT_ROOT/runtime.log"
[ "$1" != compose ] || shift
case "$1" in
    version) exit 0 ;;
    config) echo database; exit 0 ;;
    exec) shift ;;
    *) exit 90 ;;
esac
while [[ "$1" == -* ]]; do
    case "$1" in
        --user) export MOCK_USER="$2"; shift 2 ;;
        --workdir) cd "$2" || exit; shift 2 ;;
        --env) export "$2"; shift 2 ;;
        *) shift ;;
    esac
done
shift
export IN_TARGET=yes
export PATH="$AUDIT_ROOT/targetbin:/usr/bin:/bin"
exec "$@"
EOF
    chmod +x "$root/hostbin/runtime"
    for runtime in docker podman docker-compose; do
        ln -s runtime "$root/hostbin/$runtime"
    done
    cat > "$root/targetbin/id" <<'EOF'
#!/bin/sh
case "$1" in
    -un) echo dbos ;;
    -u)
        case "$2" in
            "") echo "$MOCK_UID" ;;
            dbos) echo 1001 ;;
            *) echo 2002 ;;
        esac ;;
    *) exit 91 ;;
esac
EOF
    cat > "$root/targetbin/getent" <<'EOF'
#!/bin/sh
[ "$2" != missing ] || exit 2
printf '%s:x:1001:1001::%s/home:/bin/sh\n' "$2" "$AUDIT_ROOT"
EOF
    cat > "$root/targetbin/su" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$AUDIT_ROOT/su.log"
[ "$ALLOW_SU" = yes ] || { echo 'unexpected su' >&2; exit 92; }
while [ "$#" -gt 0 ]; do
    case "$1" in
        -l) shift ;;
        -s) shift 2 ;;
        -c) script=$2; shift 2 ;;
        *) shift ;;
    esac
done
exec /bin/sh -c "$script"
EOF
    cat > "$root/targetbin/chown" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$AUDIT_ROOT/chown.log"
EOF
    cat > "$root/targetbin/mktemp" <<'EOF'
#!/bin/sh
case "$1" in
    /tmp/backupninja-mysql.*)
        [ "$IN_TARGET" = yes ] || exit 93
        [ -z "$FAIL_MKTEMP" ] || exit 21
        path=$(/usr/bin/mktemp "$AUDIT_ROOT/tmp/backupninja-mysql.XXXXXX") || exit
        printf '%s\n' "$path" > "$AUDIT_ROOT/created-credentials"
        printf '%s\n' "$path" ;;
    *) exec /usr/bin/mktemp "$@" ;;
esac
EOF
    cat > "$root/targetbin/cat" <<'EOF'
#!/bin/sh
[ -z "$FAIL_WRITE" ] || exit 22
exec /bin/cat "$@"
EOF
    cat > "$root/targetbin/rm" <<'EOF'
#!/bin/sh
case "$*" in
    *backupninja-mysql.*) [ -z "$FAIL_CLEANUP" ] || exit 23 ;;
esac
exec /bin/rm "$@"
EOF
    cat > "$root/targetbin/client" <<'EOF'
#!/bin/sh
[ "$IN_TARGET" = yes ] || exit 93
name=${0##*/}
printf '%s|%s|%s|%s\n' "$name" "$PWD" "$BACKUP_MODE" "$*" >> "$AUDIT_ROOT/commands"
case "$name" in
    mysql|mysqladmin|mysqldump)
        case "$1" in
            --defaults-file=*|--defaults-extra-file=*)
                config=${1#*=}
                if [ -f "$config" ]; then
                    cp "$config" "$AUDIT_ROOT/credentials"
                    stat -c %a "$config" > "$AUDIT_ROOT/credential-mode"
                    printf '%s\n' "$config" > "$AUDIT_ROOT/credential-path"
                fi ;;
            *) exit 94 ;;
        esac ;;
esac
case "$name" in
    mysql) [ -z "$FAIL_LIST" ] || exit 11; printf 'app\ninformation_schema\n' ;;
    mysqladmin) [ -z "$FAIL_PING" ] || exit 12 ;;
    mysqldump|pg_dump|pg_dumpall)
        printf 'dump contents\n'
        [ -z "$FAIL_DUMP" ] || exit 13 ;;
    psql) [ -z "$FAIL_LIST" ] || exit 14; echo app ;;
    mysqlhotcopy)
        for dest do :; done
        echo hotcopy > "$dest/result" ;;
    gitlab-backup)
        printf '%s\n' "$GITLAB_BACKUP_PGPASSWORD" > "$AUDIT_ROOT/gitlab-password"
        [ -z "$FAIL_DUMP" ] || exit 15
        mkdir -p "$AUDIT_ROOT/remote"
        echo archive > "$AUDIT_ROOT/remote/archive.tar" ;;
esac
EOF
    chmod +x "$root/targetbin/"*
    for cmd in mysql mysqladmin mysqldump mysqlhotcopy pg_dump pg_dumpall psql gitlab-backup; do
        ln -s client "$root/targetbin/$cmd"
        printf '#!/bin/sh\necho HOST_COMMAND_STARTED >&2\nexit 99\n' > "$root/hostbin/$cmd"
        chmod +x "$root/hostbin/$cmd"
    done
}

write_action() {
    cat > "$root/action.conf" <<EOF
backupdir = $root/remote
databases = all
sqldump = yes
compress = no
dbusername = app_role
dbpassword = private-test-value
[transport]
transport = $1
container = database
service = database
projectdir = $root/work dir
user = dbos
workdir = $root/work dir
environment = BACKUP_MODE=target value
hostbackupdir = $root/host
EOF
    if [ "$1" = local ]; then
        export IN_TARGET=yes BACKUP_MODE="target value"
        export PATH="$root/targetbin:$PATH"
        cd "$root/work dir" || return
    fi
}

run_handler() {
    # shellcheck disable=SC1090
    . "$BATS_TEST_DIRNAME/../handlers/$1"
}

assert_credentials_cleaned() {
    [ -f "$root/credential-path" ]
    [ ! -e "$(cat "$root/credential-path")" ]
    [ "$(cat "$root/credential-mode")" = 600 ]
}

@test "MySQL auth, target PATH, non-root user, cwd and environment work with all transports" {
    echo untouched > "$root/home/.my.cnf"
    for transport in docker podman docker-compose local; do
        write_action "$transport"
        run run_handler mysql
        [ "$status" -eq 0 ]
        [[ "$output" != *private-test-value* ]]
        [ "$(cat "$root/remote/sqldump/app.sql")" = 'dump contents' ]
        grep -Fq "mysqldump|$root/work dir|target value|" "$root/commands"
        [ "$(cat "$root/home/.my.cnf")" = untouched ]
        assert_credentials_cleaned
        grep -Fxq 'user="app_role"' "$root/credentials"
        if [ "$transport" != local ]; then
            [ "$(cat "$root/host/sqldump/app.sql")" = 'dump contents' ]
            run grep -q private-test-value "$root/runtime.log"
            [ "$status" -eq 1 ]
        fi
    done
}

@test "MySQL credentials are cleaned after listing, ping and dump failures" {
    for failure in FAIL_LIST FAIL_PING FAIL_DUMP; do
        write_action podman
        mkdir -p "$root/remote/sqldump" "$root/host/sqldump"
        echo previous > "$root/remote/sqldump/app.sql"
        echo previous > "$root/host/sqldump/app.sql"
        export "$failure=yes"
        run run_handler mysql
        unset "$failure"
        [ "$status" -ne 0 ]
        assert_credentials_cleaned
        [ "$(cat "$root/remote/sqldump/app.sql")" = previous ]
        [ "$(cat "$root/host/sqldump/app.sql")" = previous ]
        [ -z "$(find "$root/remote" -name '*.partial*' -print)" ]
    done
}

@test "MySQL credentials retain quotes, backslashes and option-file metacharacters" {
    write_action docker
    # Set credentials through getconf, just as parsed INI values are returned.
    getconf() {
        local value
        case "$1" in
            dbpassword) printf -v dbpassword '%s' $'a"b\\c#d;e\nnext' ;;
            *)
                value=$(awk -f "$libdirectory/parseini" "S=$CURRENT_SECTION" "P=$1" "$CURRENT_CONF_FILE")
                printf -v "$1" '%s' "${value:-$2}" ;;
        esac
    }

    run run_handler mysql
    [ "$status" -eq 0 ]
    grep -Fxq 'password="a\"b\\c#d;e\nnext"' "$root/credentials"
    assert_credentials_cleaned
}

@test "MySQL rejects hotcopy with explicit credentials or configfile before execution" {
    write_action podman
    sed -i '/sqldump =/a hotcopy = yes' "$root/action.conf"
    run run_handler mysql
    [ "$status" -eq 2 ]
    [[ "$output" = *"mysqlhotcopy does not support"* ]]
    [ ! -e "$root/commands" ]
    sed -i '/dbusername =/d; /dbpassword =/d; /sqldump =/a configfile = /target/client.cnf' "$root/action.conf"
    run run_handler mysql
    [ "$status" -eq 2 ]
    [[ "$output" = *"mysqlhotcopy does not support"* ]]
    [ ! -e "$root/commands" ]
}

@test "hotcopy resolves the executable in the target and keeps implicit home authentication" {
    write_action podman
    sed -i '/dbusername =/d; /dbpassword =/d; s/sqldump = yes/sqldump = no/; /sqldump =/a hotcopy = yes' "$root/action.conf"
    run run_handler mysql
    [ "$status" -eq 0 ]
    [ "$(cat "$root/host/hotcopy/result")" = hotcopy ]
}

@test "MySQL retains user-home and extra-file authentication" {
    for method in user configfile; do
        write_action podman
        sed -i '/dbusername =/d; /dbpassword =/d' "$root/action.conf"
        echo '[client]' > "$root/home/.my.cnf"
        if [ "$method" = user ]; then
            sed -i '1i user = dbos' "$root/action.conf"
        else
            sed -i "1i configfile = $root/home/.my.cnf" "$root/action.conf"
        fi
        run run_handler mysql
        [ "$status" -eq 0 ]
        grep -Fq -- "--defaults-extra-file=$root/home/.my.cnf" "$root/commands"
    done
}

@test "PostgreSQL preserves container environment and cwd without su or chown as its OS user" {
    for transport in docker podman docker-compose local; do
        write_action "$transport"
        run run_handler pgsql
        [ "$status" -eq 0 ]
        grep -Fq "pg_dumpall|$root/work dir|target value|-U app_role" "$root/commands"
        [ -s "$root/remote/$(hostname)-all.sql" ]
        [ ! -e "$root/su.log" ]
        [ ! -e "$root/chown.log" ]
    done
}

@test "PostgreSQL custom format listing, globals and compressed dumps run in the target" {
    write_action docker
    sed -i '1i format = custom\ncompress = yes' "$root/action.conf"
    # A parameter must occur once (repeated INI parameters are lists).
    sed -i '/compress = no/d' "$root/action.conf"
    run run_handler pgsql
    [ "$status" -eq 0 ]
    gzip -t "$root/host/app.pg_dump.gz" "$root/host/globals.sql.gz"
    grep -Fq "psql|$root/work dir|target value|" "$root/commands"
}

@test "PostgreSQL failed dump propagates status and protects target and host output" {
    write_action podman
    sed -i 's/databases = all/databases = app/' "$root/action.conf"
    mkdir -p "$root/remote" "$root/host"
    echo previous > "$root/remote/app.sql"
    echo previous > "$root/host/app.sql"
    export FAIL_DUMP=yes
    run run_handler pgsql
    [ "$status" -ne 0 ]
    [ "$(cat "$root/remote/app.sql")" = previous ]
    [ "$(cat "$root/host/app.sql")" = previous ]
    [ -z "$(find "$root/remote" -name '*.partial*' -print)" ]
}

@test "non-root transport cannot silently switch to a different system user" {
    write_action podman
    printf -v PGSQLUSER '%s' otheros
    run run_handler pgsql
    [ "$status" -ne 0 ]
    [[ "$output" = *"transport user is not root"* ]]
    [ ! -e "$root/commands" ]
}

@test "GitLab sends credentials on stdin rather than runtime argv for every transport" {
    for transport in docker podman docker-compose local; do
        write_action "$transport"
        sed -i '1i pgpassword = secret with spaces and apostrophe'\''s' "$root/action.conf"
        run run_handler gitlab
        [ "$status" -eq 0 ]
        [ "$(cat "$root/gitlab-password")" = "secret with spaces and apostrophe's" ]
        [[ "$output" != *"secret with"* ]]
        if [ "$transport" != local ]; then
            run grep -Fq 'secret with' "$root/runtime.log"
            [ "$status" -eq 1 ]
            [ "$(cat "$root/host/archive.tar")" = archive ]
        fi
    done
}

@test "GitLab failure and test mode do not fetch output" {
    write_action docker-compose
    mkdir "$root/host"
    echo previous > "$root/host/archive.tar"
    export FAIL_DUMP=yes
    run run_handler gitlab
    [ "$status" -ne 0 ]
    [ "$(cat "$root/host/archive.tar")" = previous ]
    export test=1
    run run_handler gitlab
    [ "$status" -eq 0 ]
    run grep -q ' tar ' "$root/runtime.log"
    [ "$status" -eq 1 ]
}

@test "all shipped host-only handlers reject non-local transports before being sourced" {
    for source in "$BATS_TEST_DIRNAME"/../handlers/*.in "$BATS_TEST_DIRNAME"/../handlers/wget; do
        handler=${source##*/}
        handler=${handler%.in}
        case "$handler" in Makefile|*.helper|mysql|pgsql|gitlab) continue ;; esac
        for transport in docker podman docker-compose; do
            write_action "$transport"
            run transport_check_handler "$handler"
            [ "$status" -eq 2 ]
            [[ "$output" = *"refusing to run on the host"* ]]
        done
        write_action local
        transport_check_handler "$handler"
    done
}

@test "every runtime preserves stdin, stdout, stderr and exit status" {
    for transport in docker podman docker-compose local; do
        write_action "$transport"
        transport_init
        run runcmd sh -c 'cat; printf diagnostic >&2; exit 17' <<< 'input value'
        [ "$status" -eq 17 ]
        [ "$output" = $'input value\ndiagnostic' ]
    done
}

@test "standalone docker-compose runs validation and backup in the project directory" {
    write_action docker-compose
    echo 'docker_compose = docker-compose' >> "$root/action.conf"
    run run_handler mysql
    [ "$status" -eq 0 ]
    grep -q '^config --services$' "$root/runtime.log"
    grep -q '^exec -T --user dbos ' "$root/runtime.log"
    [ -s "$root/host/sqldump/app.sql" ]
}

@test "root switches to the PostgreSQL OS user without resetting container environment" {
    write_action podman
    export MOCK_UID=0 ALLOW_SU=yes
    run run_handler pgsql
    [ "$status" -eq 0 ]
    grep -Fq "pg_dumpall|$root/work dir|target value|" "$root/commands"
    grep -q '^-s /bin/sh -c ' "$root/su.log"
    run grep -q '^-l ' "$root/su.log"
    [ "$status" -eq 1 ]
    [ -s "$root/chown.log" ]
}

@test "local PostgreSQL retains the login-shell user switch" {
    write_action local
    export MOCK_UID=0 ALLOW_SU=yes
    run run_handler pgsql
    [ "$status" -eq 0 ]
    grep -q '^-l -s /bin/sh -c ' "$root/su.log"
}

@test "MySQL credential creation and write failures are fatal and cleaned up" {
    for failure in FAIL_MKTEMP FAIL_WRITE; do
        write_action podman
        export "$failure=yes"
        run run_handler mysql
        unset "$failure"
        [ "$status" -eq 2 ]
        [ ! -e "$root/commands" ]
        [ -z "$(find "$root/tmp" -name 'backupninja-mysql.*' -print)" ]
        [ ! -e "$root/host" ]
    done
}

@test "MySQL credential cleanup failure is explicit and prevents host installation" {
    write_action podman
    export FAIL_CLEANUP=yes
    run run_handler mysql
    [ "$status" -ne 0 ]
    [[ "$output" = *"Can't remove temporary MySQL credentials"* ]]
    [ ! -e "$root/host" ]
    [ -f "$(cat "$root/created-credentials")" ]
}

@test "database executable paths containing spaces are quoted in target shell commands" {
    mkdir "$root/target bin"
    ln -s "$root/targetbin/client" "$root/target bin/mysqldump"
    ln -s "$root/targetbin/client" "$root/target bin/pg_dump"
    printf -v MYSQLDUMP '%s' "$root/target bin/mysqldump"
    printf -v PGSQLDUMP '%s' "$root/target bin/pg_dump"
    write_action docker
    run run_handler mysql
    [ "$status" -eq 0 ]
    [ "$(cat "$root/host/sqldump/app.sql")" = 'dump contents' ]
    sed -i 's/databases = all/databases = app/' "$root/action.conf"
    run run_handler pgsql
    [ "$status" -eq 0 ]
    [ "$(cat "$root/host/app.sql")" = 'dump contents' ]
}
