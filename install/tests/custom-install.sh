#!/usr/bin/env bash

# Tests that an installation using custom paths works properly.
# WARNING: this test makes changes to the local filesystem and is intended to be run in a containerized environment.

set -o errexit
source ./test-util.sh

export CUSTOM_HOME_DIR="$(pwd)custom-test-home"
export CUSTOM_BIN_DIR="$CUSTOM_HOME_DIR/bin"
export PATH="$CUSTOM_BIN_DIR:$PATH"

touch "$HOME/.profile"
cp "$HOME/.profile" "$HOME/.profile.bak"
cleanup () {
    set +o errexit

    mv "$HOME/.profile.bak" "$HOME/.profile"

    if has_command "swiftly" ; then
       swiftly uninstall -y latest > /dev/null
    fi

    rm -r "$CUSTOM_HOME_DIR"
}
trap cleanup EXIT

# Swiftly needs these things at a minimum and will abort telling the user
#  if they are missing.
if has_command apt-get ; then
    apt-get update
    apt-get install -y ca-certificates gpg # These are needed for swiftly
elif has_command yum ; then
    yum install -y ca-certificates gpg # These are needed for swiftly to function
fi

# Custom home dir
# Custom bin dir
# Modify login config (yes)
printf "1\n" | SWIFTLY_HOME_DIR="$CUSTOM_HOME_DIR" SWIFTLY_BIN_DIR="$CUSTOM_BIN_DIR" $(get_swiftly) init

# .profile should be updated to update PATH and SWIFTLY_HOME_DIR/SWIFTLY_BIN_DIR.
bash --login -c "swiftly --version"

. "$CUSTOM_HOME_DIR/env.sh"

if ! has_command "swiftly" ; then
    test_fail "Can't find swiftly on the PATH"
fi

if [[ "$SWIFTLY_HOME_DIR" != "$CUSTOM_HOME_DIR" ]]; then
    test_fail "SWIFTLY_HOME_DIR ($SWIFTLY_HOME_DIR) did not equal $CUSTOM_HOME_DIR"
fi

if [[ "$SWIFTLY_BIN_DIR" != "$CUSTOM_BIN_DIR" ]]; then
    test_fail "SWIFTLY_BIN_DIR ($SWIFTLY_BIN_DIR) did not equal $CUSTOM_BIN_DIR"
fi

if [[ ! -d "$CUSTOM_HOME_DIR/toolchains" ]]; then
    test_fail "the toolchains directory was not created in SWIFTLY_HOME_DIR"
fi

if [[ -d "$HOME/.local/share/swiftly" ]]; then
    test_fail "expected default home directory to not be created, but it was"
fi

swiftly install 5.10.0 || echo "expected that the install exits with 1 to indicate that system dependencies need to be installed"

# The user would have been instructed to install the system dependencies
# after installing the toolchain. Pre-install those now.
install_system_deps

swift --version

if [[ ! -d "$CUSTOM_HOME_DIR/toolchains/5.10.0" ]]; then
    test_fail "the toolchain was not installed to the custom directory"
fi

if [[ -d "$HOME/.local/share/swiftly" ]]; then
    test_fail "expected default home directory to not be created, but it was"
fi

test_pass
