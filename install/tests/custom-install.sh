#!/usr/bin/env bash

# Tests that an installation using custom paths works properly.
# WARNING: this test makes changes to the local filesystem and is intended to be run in a containerized environment.

set -o errexit
source ./test-util.sh

export CUSTOM_HOME_DIR="$(pwd)custom-test-home"
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

printf "2\n$CUSTOM_HOME_DIR\n$CUSTOM_BIN_DIR\n1\n" | ./swiftly-install.sh

export SWIFTLY_HOME_DIR="$CUSTOM_HOME_DIR"
export SWIFTLY_BIN_DIR="$CUSTOM_BIN_DIR"

if ! has_command "swiftly" ; then
    test_fail "Can't find swiftly on the PATH"
fi

if [[ ! -d "$CUSTOM_HOME_DIR/toolchains" ]]; then
    test_fail "the toolchains directory was not created in SWIFTLY_HOME_DIR"
fi

if [[ -d "$HOME/.local/share/swiftly" ]]; then
    test_fail "expected default home directory to not be created, but it was"
fi

swiftly install 5.7.3

swift --version

if [[ ! -d "$CUSTOM_HOME_DIR/toolchains/5.7.3" ]]; then
    test_fail "the toolchain was not installed to the custom directory"
fi

if [[ -d "$HOME/.local/share/swiftly" ]]; then
    test_fail "expected default home directory to not be created, but it was"
fi

test_pass
