#!/bin/bash

# A minimal testsuite for backupninja
set -euo pipefail

# This is meant to be run inside a development environment,
# so give the user a chance to bail
if [ ! -d "/vagrant" ]; then
    read -p "This doesn't look like a test environment (Vagrant). Continue anyway? " -n 1 -r
	if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

# Are we root?
if [[ "$EUID" -ne 0 ]]; then
    echo "Please run the test suite as root."
    exit 1
fi

# Is backupninja in $PATH ?
if ! command -v backupninja >/dev/null; then
    echo "Couldn't find 'backupninja', is it installed?"
    exit 1
fi

testdir=$(cd "$(dirname "$0")" && pwd)
tests=()
if (( $# == 0 )); then
    tests=("$testdir"/*.bats)
else
    for handler in "$@"; do
        if [[ ! "$handler" =~ ^[a-z][a-z0-9_-]*$ || ! -f "$testdir/$handler.bats" ]]; then
            echo "Unknown test handler: $handler" >&2
            exit 2
        fi
        tests+=("$testdir/$handler.bats")
    done
fi

# Install basic test dependencies
DEBIAN_FRONTEND=noninteractive apt-get install -y bats mailutils faketime crudini

# Create a temporary base directory
TMPDIR=$(mktemp -t -d bntest.XXXXXX)
export TMPDIR
tmp_mounted=0
backups_mounted=0
# ShellCheck cannot follow this EXIT trap after the final dynamic exit.
# shellcheck disable=SC2317
cleanup() {
    status=$?
    trap - EXIT
    if (( tmp_mounted )); then
        umount "$TMPDIR" || status=1
    fi
    if (( backups_mounted )); then
        umount /var/backups || status=1
    fi
    rmdir "$TMPDIR" || status=1
    exit "$status"
}
trap 'cleanup' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Mount temporary directories in tmpfs
# this should speed up the tests a little bit
mount -t tmpfs tmpfs "$TMPDIR"
tmp_mounted=1
mount -t tmpfs tmpfs /var/backups
backups_mounted=1

# Run actual tests
status=0
for t in "${tests[@]}"; do
    echo "# $(basename -s .bats "$t")"
    bats "$t" || status=1
    echo
done
exit "$status"
