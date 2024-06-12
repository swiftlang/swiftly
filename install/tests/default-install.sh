#!/usr/bin/env bash

# Tests that an unconfigured installation works properly.
# WARNING: this test makes changes to the local filesystem and is intended to be run in a containerized environment.

set -o errexit
source ./test-util.sh

touch "$HOME/.profile"
cp "$HOME/.profile" "$HOME/.profile.bak"

cleanup () {
    set +o errexit

    mv "$HOME/.profile.bak" "$HOME/.profile"

    if has_command "swiftly" ; then
       swiftly uninstall -y latest > /dev/null
    fi

    rm -r "$HOME/.local/share/swiftly"
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

printf "\n" | $(get_swiftly) init

$(get_swiftly) install latest || echo "the install completes but exits with 1 to indicate that further action is necessary"

# The user will be told to ensure that the system deps are installed before continuing
install_system_deps

# .profile should be updated to update PATH.
bash --login -c "swiftly --version"

. "$HOME/.local/share/swiftly/env.sh"

if ! has_command "swiftly" ; then
    test_fail "Can't find swiftly on the PATH"
fi

if [[ ! -d "$HOME/.local/share/swiftly/toolchains" ]]; then
    test_fail "the toolchains directory was not created in SWIFTLY_HOME_DIR"
fi

swiftly install latest

if ! gpg --list-keys Swift ; then
    test_fail "Swift PGP keys were not installed by default."
fi

swift --version

test_pass
