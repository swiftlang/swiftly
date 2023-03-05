#!/usr/bin/env bash

# Tests that swiftly-install properly handles an existing installation of swiftly.
# Run this from the root of the repository.
# WARNING: this test makes changes to the local filesystem and is intended to be run in a containerized environment.

set -o errexit
source ./scripts/tests/util.sh

export SWIFTLY_HOME_DIR="./overwrite-test-home"
export SWIFTLY_BIN_DIR="$SWIFTLY_HOME_DIR/bin"
export PATH="$SWIFTLY_BIN_DIR:$PATH"

cleanup () {
    rm -r "$SWIFTLY_HOME_DIR"
}
trap cleanup EXIT

./swiftly-install.sh -y

if ! has_command "swiftly" ; then
    test_fail "Can't find swiftly on the PATH"
fi

swiftly install 5.7.3

INSTALLED_TOOLCHAINS="$(jq .installedToolchains $SWIFTLY_HOME_DIR/config.json)"

# Attempt the same installation, but decline to overwrite.
printf "1\nn\n" | ./swiftly-install.sh 

if ! has_command "swiftly" ; then
    test_fail "Can't find swiftly on the PATH"
fi

NEW_INSTALLED_TOOLCHAINS="$(jq .installedToolchains $SWIFTLY_HOME_DIR/config.json)"
if [ "$NEW_INSTALLED_TOOLCHAINS" != "$INSTALLED_TOOLCHAINS" ]; then
    test_fail "Expected config to remain unchanged" "$NEW_INSTALLED_TOOLCHAINS" "$INSTALLED_TOOLCHAINS"
fi

if [ ! -d "$SWIFTLY_HOME_DIR/toolchains/5.7.3" ]; then
    test_fail "Expected installed toolchain directory to still exist, but it has been deleted"
fi

# Attempt the same installation, but overwrite this time.
printf "1\ny\n" | ./swiftly-install.sh 

if ! has_command "swiftly" ; then
    test_fail "Can't find swiftly on the PATH"
fi

NEW_INSTALLED_TOOLCHAINS="$(jq .installedToolchains $SWIFTLY_HOME_DIR/config.json)"
if [ "$NEW_INSTALLED_TOOLCHAINS" != "[]" ]; then
    test_fail "Expected config's list of installed toolchains to be reset" "$NEW_INSTALLED_TOOLCHAINS" "[]"
fi

if [ -d "$SWIFTLY_HOME_DIR/toolchains/5.7.3" ]; then
    test_fail "Expected installed toolchain directory to have been overwritten, but it still exists"
fi

swiftly --version

test_pass
