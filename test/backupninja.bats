load common

begin_backupninja() {
    install_pkgs faketime mailutils prometheus-node-exporter rsync
    useradd ci_user
    echo "root: ci_user" >> /etc/aliases

    remote_install_pkgs rsync
}

teardown_backupninja() {
    [ -x /usr/bin/mail.moved ] && mv /usr/bin/mail.moved /usr/bin/mail
    [ -x /usr/bin/rsync.moved ] && mv /usr/bin/rsync.moved /usr/bin/rsync
    rm -f /var/mail/ci_user
    rm -f /var/lib/prometheus/node-exporter/backupninja.prom
}

create_test_action() {
    echo '#!/bin/sh' > "${BATS_TMPDIR}/backup.d/test.sh"
    echo "$1 $2" >> "${BATS_TMPDIR}/backup.d/test.sh"
    chmod 0750 "${BATS_TMPDIR}/backup.d/test.sh"
}

@test "general: usage information is displayed" {
    run backupninja --help
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "/usr/sbin/backupninja usage:" ]
}

@test "general: error thrown on bad command-line option" {
    run backupninja --foo
    [ "$status" -eq 3 ]
    echo "${lines[0]}" | grep -q "Error: Unknown option --foo"
}

@test "general: error thrown on attempt to run as non-root user" {
    run runuser -u ci_user -- backupninja -f "${BATS_TMPDIR}/backupninja.conf"
    [ "$status" -eq 3 ]
    [ "${lines[1]}" = "backupninja can only be run as root" ]
}

@test "general: logfile is created" {
    run backupninja -f "${BATS_TMPDIR}/backupninja.conf"
    [ "$status" -eq 0 ]
    [ -f "${BATS_TMPDIR}/log/backupninja.log" ]
}

@test "general: no backup actions configured is logged" {
    run backupninja --test -f "${BATS_TMPDIR}/backupninja.conf"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "Info: No backup actions configured in '${BATS_TMPDIR}/backup.d', run ninjahelper!" ]
}

@test "general: file without suffix in action directory is ignored" {
    touch "${BATS_TMPDIR}/backup.d/test"
    chmod 0640 "${BATS_TMPDIR}/backup.d/test"
    run backupninja -f "${BATS_TMPDIR}/backupninja.conf"
    [ "$status" -eq 0 ]
    grep -q "Info: Skipping ${BATS_TMPDIR}/backup.d/test" "${BATS_TMPDIR}/log/backupninja.log"
}

@test "permissions: error thrown when backup action is owned by non-root user" {
    create_test_action
    chown ci_user: "${BATS_TMPDIR}/backup.d/test.sh"
    run backupninja -f "${BATS_TMPDIR}/backupninja.conf"
    [ "$status" -eq 2 ]
    echo "${lines[0]}" | grep -qe '^Configuration files must be owned by root!'
}

@test "permissions: error thrown when backup action is world readable" {
    create_test_action
    chmod 0755 "${BATS_TMPDIR}/backup.d/test.sh"
    run backupninja -f "${BATS_TMPDIR}/backupninja.conf"
    [ "$status" -eq 2 ]
    echo "${lines[0]}" | grep -qe '^Configuration files must not be world writable/readable!'
}

@test "permissions: error thrown when backup action group ownership is bad" {
    create_test_action
    chgrp staff "${BATS_TMPDIR}/backup.d/test.sh"
    run backupninja --now -f "${BATS_TMPDIR}/backupninja.conf"
    [ "$status" -eq 2 ]
    echo "${lines[0]}" | grep -qe '^Configuration files must not be writable/readable by group staff!'
}

@test "permissions: admingroup allows non-root group ownership of backup action" {
    create_test_action
    setconfig backupninja.conf admingroup staff
    chgrp staff "${BATS_TMPDIR}/backup.d/test.sh"
    run backupninja --now -f "${BATS_TMPDIR}/backupninja.conf"
    [ "$status" -eq 0 ]
}

@test "reports: report is mailed when halts > 0" {
    create_test_action halt test_halt
    run backupninja --now -f "${BATS_TMPDIR}/backupninja.conf" --run "${BATS_TMPDIR}/backup.d/test.sh"
    sleep 0.1
    grep -q "\*halt\* -- ${BATS_TMPDIR}/backup.d/test.sh" /var/mail/ci_user
}

@test "reports: report is mailed when fatals > 0" {
    create_test_action fatal test_error
    run backupninja --now -f "${BATS_TMPDIR}/backupninja.conf" --run "${BATS_TMPDIR}/backup.d/test.sh"
    sleep 0.1
    grep -q "\*failed\* -- ${BATS_TMPDIR}/backup.d/test.sh" /var/mail/ci_user
}

@test "reports: report is mailed when reportwarning = yes and warnings > 0" {
    create_test_action warning test_warning
    setconfig backupninja.conf reportsuccess no
    setconfig backupninja.conf reportwarning yes
    run backupninja --now -f "${BATS_TMPDIR}/backupninja.conf" --run "${BATS_TMPDIR}/backup.d/test.sh"
    sleep 0.1
    grep -q "Warning: test_warning" /var/mail/ci_user
}

@test "reports: report is mailed when reportsuccess = yes" {
    create_test_action info test_info
    setconfig backupninja.conf reportsuccess yes
    run backupninja --now -f "${BATS_TMPDIR}/backupninja.conf" --run "${BATS_TMPDIR}/backup.d/test.sh"
    sleep 0.1
    grep -q "success -- ${BATS_TMPDIR}/backup.d/test.sh" /var/mail/ci_user
}

@test "reports: success report contains informational messages" {
    create_test_action info test_info
    setconfig backupninja.conf reportsuccess yes
    setconfig backupninja.conf reportinfo yes
    run backupninja --now -f "${BATS_TMPDIR}/backupninja.conf" --run "${BATS_TMPDIR}/backup.d/test.sh"
    sleep 0.1
    grep -q "Info: test_info" /var/mail/ci_user
}

@test "reports: success report contains disk space info" {
    create_test_action info test_info
    echo "directory = /" >> "${BATS_TMPDIR}/backup.d/test.sh"
    setconfig backupninja.conf reportsuccess yes
    setconfig backupninja.conf reportspace yes
    run backupninja --now -f "${BATS_TMPDIR}/backupninja.conf" --run "${BATS_TMPDIR}/backup.d/test.sh"
    sleep 0.1
    grep -q "Use%" /var/mail/ci_user
}

@test "reports: emits error if mail executable is not found" {
    create_test_action info test_info
    setconfig backupninja.conf reportsuccess yes
    mv /usr/bin/mail /usr/bin/mail.moved
    run backupninja --now -f "${BATS_TMPDIR}/backupninja.conf" --run "${BATS_TMPDIR}/backup.d/test.sh"
    [ "$status" -eq 1 ]
}

@test "reports: wraps report text to 1000 columns by default" {
    create_test_action info "$(printf \'=%.0s\' {1..2000})"
    setconfig backupninja.conf reportsuccess yes
    setconfig backupninja.conf reportinfo yes
    run backupninja --now -f "${BATS_TMPDIR}/backupninja.conf" --run "${BATS_TMPDIR}/backup.d/test.sh"
    sleep 0.1
    grep -q '^=\{1000\}$' /var/mail/ci_user
}

@test "reports: wraps report text according to reportwrap" {
    create_test_action info "$(printf \'=%.0s\' {1..2000})"
    setconfig backupninja.conf reportsuccess yes
    setconfig backupninja.conf reportinfo yes
    setconfig backupninja.conf reportwrap 100
    run backupninja --now -f "${BATS_TMPDIR}/backupninja.conf" --run "${BATS_TMPDIR}/backup.d/test.sh"
    sleep 0.1
    grep -q '^=\{100\}$' /var/mail/ci_user
}

@test "reports: reporthost sends report to remote host" {
    cleanup_backups remote
    create_test_action info test_info
    setconfig backupninja.conf reportsuccess yes
    setconfig backupninja.conf reportinfo yes
    setconfig backupninja.conf reporthost "$BN_REMOTEHOST"
    setconfig backupninja.conf reportuser "$BN_REMOTEUSER"
    setconfig backupninja.conf reportdirectory "$BN_BACKUPDIR"
    run backupninja --now -f "${BATS_TMPDIR}/backupninja.conf" --run "${BATS_TMPDIR}/backup.d/test.sh"
    [ "$status" -eq 0 ]
    ssh "${BN_REMOTEUSER}@${BN_REMOTEHOST}" test -s "${BN_BACKUPDIR}/backupninja.log"
}

@test "reports: emits error when reportuser is empty" {
    create_test_action info test_info
    setconfig backupninja.conf reportsuccess yes
    setconfig backupninja.conf reportinfo yes
    setconfig backupninja.conf reporthost "$BN_REMOTEHOST"
    setconfig backupninja.conf reportdirectory "$BN_BACKUPDIR"
    run backupninja --now -f "${BATS_TMPDIR}/backupninja.conf" --run "${BATS_TMPDIR}/backup.d/test.sh"
    [ "$status" -eq 1 ]
}

@test "reports: emits error when reportdirectory is empty" {
    create_test_action info test_info
    setconfig backupninja.conf reportsuccess yes
    setconfig backupninja.conf reportinfo yes
    setconfig backupninja.conf reporthost "$BN_REMOTEHOST"
    setconfig backupninja.conf reportuser "$BN_REMOTEUSER"
    run backupninja --now -f "${BATS_TMPDIR}/backupninja.conf" --run "${BATS_TMPDIR}/backup.d/test.sh"
    [ "$status" -eq 1 ]
}

@test "reports: emits error when rsync is not found" {
    create_test_action info test_info
    setconfig backupninja.conf reportsuccess yes
    setconfig backupninja.conf reportinfo yes
    setconfig backupninja.conf reporthost "$BN_REMOTEHOST"
    setconfig backupninja.conf reportuser "$BN_REMOTEUSER"
    mv /usr/bin/rsync /usr/bin/rsync.moved
    run backupninja --now -f "${BATS_TMPDIR}/backupninja.conf" --run "${BATS_TMPDIR}/backup.d/test.sh"
    [ "$status" -eq 1 ]
}

@test "reports: emits error when reporthost is invalid" {
    create_test_action info test_info
    setconfig backupninja.conf reportsuccess yes
    setconfig backupninja.conf reportinfo yes
    setconfig backupninja.conf reporthost foo
    setconfig backupninja.conf reportuser "$BN_REMOTEUSER"
    setconfig backupninja.conf reportdirectory "$BN_BACKUPDIR"
    run backupninja --now -f "${BATS_TMPDIR}/backupninja.conf" --run "${BATS_TMPDIR}/backup.d/test.sh"
    [ "$status" -eq 1 ]
}

@test "reports: emits error when reportuser is invalid" {
    create_test_action info test_info
    setconfig backupninja.conf reportsuccess yes
    setconfig backupninja.conf reportinfo yes
    setconfig backupninja.conf reporthost "$BN_REMOTEHOST"
    setconfig backupninja.conf reportuser foo
    setconfig backupninja.conf reportdirectory "$BN_BACKUPDIR"
    run backupninja --now -f "${BATS_TMPDIR}/backupninja.conf" --run "${BATS_TMPDIR}/backup.d/test.sh"
    [ "$status" -eq 1 ]
}

@test "reports: emits error when reportdirectory is unwritable" {
    create_test_action info test_info
    setconfig backupninja.conf reportsuccess yes
    setconfig backupninja.conf reportinfo yes
    setconfig backupninja.conf reporthost "$BN_REMOTEHOST"
    setconfig backupninja.conf reportuser "$BN_REMOTEUSER"
    setconfig backupninja.conf reportdirectory "/unwritable"
    run backupninja --now -f "${BATS_TMPDIR}/backupninja.conf" --run "${BATS_TMPDIR}/backup.d/test.sh"
    [ "$status" -eq 1 ]
}

@test "reports: email not sent when reportemail is no" {
    create_test_action info test_info
    setconfig backupninja.conf reportsuccess yes
    setconfig backupninja.conf reportinfo yes
    setconfig backupninja.conf reportemail no
    run backupninja --now -f "${BATS_TMPDIR}/backupninja.conf" --run "${BATS_TMPDIR}/backup.d/test.sh"
    [ "$status" -eq 0 ]
    ! test -f /var/mail/ci_user
}

@test "reports: writes prometheus metrics when reportprom is yes" {
    create_test_action info test_info
    setconfig backupninja.conf reportprom yes
    run backupninja --now -f "${BATS_TMPDIR}/backupninja.conf" --run "${BATS_TMPDIR}/backup.d/test.sh"
    [ "$status" -eq 0 ]
    grep -q "^backupninja_actions{host=\"$(hostname)\"} 1$" /var/lib/prometheus/node-exporter/backupninja.prom
}

@test "scheduling: runs when = 'everyday at 01' and time matches" {
    create_test_action info test_info
    setconfig backupninja.conf when 'everyday at 01'
    run faketime -f '@2018-06-12 01:00:00' backupninja -f "${BATS_TMPDIR}/backupninja.conf"
    [ "$status" -eq 0 ]
    grep -q "Info: FINISHED: 1 actions run. 0 fatal. 0 error. 0 warning." "${BATS_TMPDIR}/log/backupninja.log"
}

@test "scheduling: skips when = 'everyday at 01' and time is mismatched" {
    create_test_action info test_info
    setconfig backupninja.conf when 'everyday at 01'
    run faketime -f '@2018-06-12 02:00:00' backupninja -f "${BATS_TMPDIR}/backupninja.conf"
    [ "$status" -eq 0 ]
    grep -q "Debug: skipping ${BATS_TMPDIR}/backup.d/test.sh because current time does not match everyday at 01" "${BATS_TMPDIR}/log/backupninja.log"
}

@test "scheduling: runs when = 'Tuesday at 04' and time matches" {
    create_test_action info test_info
    setconfig backupninja.conf when 'Tuesday at 04'
    run faketime -f '@2018-06-12 04:00:00' backupninja -f "${BATS_TMPDIR}/backupninja.conf"
    [ "$status" -eq 0 ]
    grep -q "Info: FINISHED: 1 actions run. 0 fatal. 0 error. 0 warning." "${BATS_TMPDIR}/log/backupninja.log"
}

@test "scheduling: skips when = 'Tuesday at 04' and time is mismatched" {
    create_test_action info test_info
    setconfig backupninja.conf when 'Tuesday at 04'
    run faketime -f '@2018-06-13 04:00:00' backupninja -f "${BATS_TMPDIR}/backupninja.conf"
    [ "$status" -eq 0 ]
    grep -q "Debug: skipping ${BATS_TMPDIR}/backup.d/test.sh because current time does not match Tuesday at 04" "${BATS_TMPDIR}/log/backupninja.log"
}

@test "scheduling: runs when = '1st at 10' and time matches" {
    create_test_action info test_info
    setconfig backupninja.conf when '1st at 10'
    run faketime -f '@2018-06-01 10:00:00' backupninja -f "${BATS_TMPDIR}/backupninja.conf"
    [ "$status" -eq 0 ]
    grep -q "Info: FINISHED: 1 actions run. 0 fatal. 0 error. 0 warning." "${BATS_TMPDIR}/log/backupninja.log"
}

@test "scheduling: skips when = '1st at 10' and time is mismatched" {
    create_test_action info test_info
    setconfig backupninja.conf when '1st at 10'
    run faketime -f '@2018-06-15 10:00:00' backupninja -f "${BATS_TMPDIR}/backupninja.conf"
    [ "$status" -eq 0 ]
    grep -q "Debug: skipping ${BATS_TMPDIR}/backup.d/test.sh because current time does not match 1st at 10" "${BATS_TMPDIR}/log/backupninja.log"
}

@test "scheduling: runs when = '21 at 09:00' and time matches" {
    create_test_action info test_info
    setconfig backupninja.conf when '21 at 09:00'
    run faketime -f '@2018-06-21 09:00:00' backupninja -f "${BATS_TMPDIR}/backupninja.conf"
    [ "$status" -eq 0 ]
    grep -q "Info: FINISHED: 1 actions run. 0 fatal. 0 error. 0 warning." "${BATS_TMPDIR}/log/backupninja.log"
}

@test "scheduling: skips when = '21 at 09:00' and time is mismatched" {
    create_test_action info test_info
    setconfig backupninja.conf when '21 at 09:00'
    run faketime -f '@2018-06-22 09:00:00' backupninja -f "${BATS_TMPDIR}/backupninja.conf"
    [ "$status" -eq 0 ]
    grep -q "Debug: skipping ${BATS_TMPDIR}/backup.d/test.sh because current time does not match 21 at 09:00" "${BATS_TMPDIR}/log/backupninja.log"
}

@test "exit code: rc=2 when halt error raised in handler" {
    create_test_action halt test_halt
    run backupninja --now -f "${BATS_TMPDIR}/backupninja.conf" --run "${BATS_TMPDIR}/backup.d/test.sh"
    [ "$status" -eq 2 ]
}

@test "exit code: rc=2 when fatal error raised in handler" {
    create_test_action fatal test_fatal
    run backupninja --now -f "${BATS_TMPDIR}/backupninja.conf" --run "${BATS_TMPDIR}/backup.d/test.sh"
    [ "$status" -eq 2 ]
}

@test "exit code: rc=1 when error raised in handler" {
    create_test_action error test_error
    run backupninja --now -f "${BATS_TMPDIR}/backupninja.conf" --run "${BATS_TMPDIR}/backup.d/test.sh"
    [ "$status" -eq 1 ]
}

@test "exit code: rc=1 when warning raised in handler and reportwarning=yes" {
    create_test_action warning test_warning
    setconfig backupninja.conf reportwarning yes
    run backupninja --now -f "${BATS_TMPDIR}/backupninja.conf" --run "${BATS_TMPDIR}/backup.d/test.sh"
    [ "$status" -eq 1 ]
}

@test "exit code: rc=0 when warning raised in handler and reportwarning=no" {
    create_test_action warning test_warning
    setconfig backupninja.conf reportwarning no
    run backupninja --now -f "${BATS_TMPDIR}/backupninja.conf" --run "${BATS_TMPDIR}/backup.d/test.sh"
    [ "$status" -eq 0 ]
}

@test "exit code: rc=0 when no warnings/errors raised in handler" {
    create_test_action "true"
    run backupninja --now -f "${BATS_TMPDIR}/backupninja.conf" --run "${BATS_TMPDIR}/backup.d/test.sh"
    [ "$status" -eq 0 ]
}
