#!/usr/bin/env bash

# Tests that swiftly-install properly handles an existing installation of swiftly.
# WARNING: this test makes changes to the local filesystem and is intended to be run in a containerized environment.

set -o errexit
source ./test-util.sh

export SWIFTLY_HOME_DIR="./overwrite-test-home"
export SWIFTLY_BIN_DIR="$SWIFTLY_HOME_DIR/bin"
export PATH="$SWIFTLY_BIN_DIR:$PATH"

cleanup () {
    rm -r "$SWIFTLY_HOME_DIR"
}
trap cleanup EXIT

SWIFTLY_READ_FROM_STDIN=1 ./swiftly-install.sh -y

if ! has_command "swiftly" ; then
    test_fail "Can't find swiftly on the PATH"
fi

# Modify the home dir to be able to to tell if it is changed with subseqent installs.
DUMMY_CONFIG_CONTENTS="hello world"
echo "$DUMMY_CONFIG_CONTENTS" > "$SWIFTLY_HOME_DIR/config.json"
mkdir "$SWIFTLY_HOME_DIR/toolchains/5.7.3"

# Attempt the same installation, but decline to overwrite.
printf "1\nn\n" | SWIFTLY_READ_FROM_STDIN=1 ./swiftly-install.sh

if ! has_command "swiftly" ; then
    test_fail "Can't find swiftly on the PATH"
fi

NEW_CONFIG_CONTENTS="$(cat $SWIFTLY_HOME_DIR/config.json)"
if [[ "$NEW_CONFIG_CONTENTS" != "$DUMMY_CONFIG_CONTENTS" ]]; then
    test_fail "Expected config to remain unchanged" "$NEW_CONFIG_CONTENTS" "$DUMMY_CONFIG_CONTENTS"
fi

if [[ ! -d "$SWIFTLY_HOME_DIR/toolchains/5.7.3" ]]; then
    test_fail "Expected installed toolchain directory to still exist, but it has been deleted"
fi

# Attempt the same installation, but overwrite this time.
printf "1\ny\n" | SWIFTLY_READ_FROM_STDIN=1 ./swiftly-install.sh

if ! has_command "swiftly" ; then
    test_fail "Can't find swiftly on the PATH"
fi

NEW_CONFIG_CONTENTS="$(cat $SWIFTLY_HOME_DIR/config.json)"
if [[ "$NEW_CONFIG_CONTENTS" == "DUMMY_CONFIG_CONTENTS" ]]; then
    test_fail "Expected config to be reset but it was not"
fi

if [[ -d "$SWIFTLY_HOME_DIR/toolchains/5.7.3" ]]; then
    test_fail "Expected installed toolchain directory to have been overwritten, but it still exists"
fi

swiftly --version

test_pass
