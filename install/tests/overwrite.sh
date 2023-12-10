#!/usr/bin/env bash

# Tests that swiftly-install properly handles an existing installation of swiftly.
# WARNING: this test makes changes to the local filesystem and is intended to be run in a containerized environment.

set -o errexit
source ./test-util.sh

export SWIFTLY_HOME_DIR="./overwrite-test-home"
export SWIFTLY_BIN_DIR="./overwrite-bin-dir"

cp "$HOME/.profile" "$HOME/.profile.bak"

cleanup () {
    mv "$HOME/.profile.bak" "$HOME/.profile"
    rm -r "$SWIFTLY_HOME_DIR"
    rm -r "$SWIFTLY_BIN_DIR"
}
trap cleanup EXIT

test_log "Performing initial installation"
./swiftly-install.sh -y --no-install-system-deps

. "$SWIFTLY_HOME_DIR/env.sh"

if ! has_command "swiftly" ; then
    test_fail "Can't find swiftly on the PATH"
fi

# Modify the home dir to be able to to tell if it is changed with subsequent installs.
DUMMY_CONFIG_CONTENTS="hello world"
PROFILE_CONTENTS="$(cat $HOME/.profile)"
echo "$DUMMY_CONFIG_CONTENTS" > "$SWIFTLY_HOME_DIR/config.json"

toolchain_dir="$SWIFTLY_HOME_DIR/toolchains/5.7.3"
mkdir -p "$toolchain_dir/usr/bin"
dummy_executable_name="foo"
touch "$toolchain_dir/usr/bin/$dummy_executable_name"

# Also set up a symlink as if the toolchain were in use.
ln -s -t $SWIFTLY_BIN_DIR "$toolchain_dir/usr/bin/$dummy_executable_name"

test_log "Attempting the same installation (no --overwrite flag specified)"
./swiftly-install.sh -y --no-install-system-deps

if ! has_command "swiftly" ; then
    test_fail "Can't find swiftly on the PATH"
fi

NEW_CONFIG_CONTENTS="$(cat $SWIFTLY_HOME_DIR/config.json)"
if [[ "$NEW_CONFIG_CONTENTS" != "$DUMMY_CONFIG_CONTENTS" ]]; then
    test_fail "Expected config to remain unchanged" "$NEW_CONFIG_CONTENTS" "$DUMMY_CONFIG_CONTENTS"
fi

if ! [ -L "$SWIFTLY_BIN_DIR/$dummy_executable_name" ]; then
    test_fail "Expected symlink to still exist, but it has been deleted"
fi

if [[ ! -d "$SWIFTLY_HOME_DIR/toolchains/5.7.3" ]]; then
    test_fail "Expected installed toolchain directory to still exist, but it has been deleted"
fi

test_log "Attempting the same installation (--overwrite flag is specified)"
./swiftly-install.sh -y --overwrite --no-install-system-deps

if ! has_command "swiftly" ; then
    test_fail "Can't find swiftly on the PATH"
fi

NEW_CONFIG_CONTENTS="$(cat $SWIFTLY_HOME_DIR/config.json)"
if [[ "$NEW_CONFIG_CONTENTS" == "DUMMY_CONFIG_CONTENTS" ]]; then
    test_fail "Expected config to be reset but it was not"
fi

if [[ "$(cat $HOME/.profile)" != "$PROFILE_CONTENTS" ]]; then
    test_fail "Expected .profile not to be updated on overwrite install"
fi

if [[ -d "$SWIFTLY_HOME_DIR/toolchains/5.7.3" ]]; then
    test_fail "Expected installed toolchain directory to have been overwritten, but it still exists"
fi

if [ -L "$SWIFTLY_BIN_DIR/$dummy_executable_name" ]; then
    test_fail "Expected symlink to have been deleted, but it still exists"
fi

swiftly --version

test_pass
