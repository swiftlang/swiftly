#!/usr/bin/env bash

# Tests that custom install paths that include the "~" character are expanded properly.
# WARNING: this test makes changes to the local filesystem and is intended to be run in a containerized environment.

set -o errexit
source ./test-util.sh

export CUSTOM_HOME_DIR_NAME="tilde-substitution-test-home"
export CUSTOM_HOME_DIR="$HOME/$CUSTOM_HOME_DIR_NAME"
export CUSTOM_BIN_DIR="$CUSTOM_HOME_DIR/bin"
export PATH="$CUSTOM_BIN_DIR:$PATH"

cleanup () {
    set +o errexit

    if has_command "swiftly" ; then
       swiftly uninstall -y latest > /dev/null
    fi

    rm -r "$CUSTOM_HOME_DIR"
}
trap cleanup EXIT

# Make sure that the "~" character is handled properly.
printf "2\n~/${CUSTOM_HOME_DIR_NAME}\n~/${CUSTOM_HOME_DIR_NAME}/bin\n1\n" | ./swiftly-install.sh

if ! has_command "swiftly" ; then
    test_fail "Can't find swiftly on the PATH"
fi

if [ ! -d "$CUSTOM_HOME_DIR/toolchains" ]; then
    test_fail "the toolchains directory was not created in SWIFTLY_HOME_DIR"
fi

export SWIFTLY_HOME_DIR="$CUSTOM_HOME_DIR"
export SWIFTLY_BIN_DIR="$CUSTOM_BIN_DIR"

swiftly install latest

swift --version

test_pass
