#!/bin/bash

# A minimal testsuite for backupninja

# This is meant to be run inside a development environment,
# so give the user a chance to bail
if [ -z "$CI" ]; then
    read -p "This doesn't look like a test environment. Continue anyway? " -n 1 -r
	if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

# Is backupninja in $PATH ?
if [ ! "$(which backupninja)" ]; then
    echo "Couldn't find 'backupninja', is it installed?"
    exit 1
fi

# Install basic test dependencies
DEBIAN_FRONTEND=noninteractive \
    apt install -y bats mailutils faketime crudini rsync

# Create a temporary base directory
TMPDIR=$(mktemp -t -d bntest.XXXXXX)
chmod a+rX "$TMPDIR"
export TMPDIR

# Create temporary user
useradd ci_user
echo "root: ci_user" >> /etc/aliases

# Run actual tests
if [ -n "$1" ]; then
    bats "$(dirname "$0")/${1}.bats"
else
    bats "$(dirname "$0")"
fi
