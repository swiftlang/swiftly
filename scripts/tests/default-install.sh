#!/usr/bin/env bash

# Tests that an unconfigured installation works properly.
# Run this from the root of the repository.
# WARNING: this test makes changes to the local filesystem and is intended to be run in a containerized environment.

set -o errexit
source ./scripts/tests/util.sh

cleanup () {
    if has_command "swiftly" ; then
       swiftly uninstall -y latest > /dev/null
    fi

    rm -r "$HOME/.local/share/swiftly"
    rm -r "$HOME/.local/bin/swiftly"
}
trap cleanup EXIT

export PATH="$HOME/.local/bin:$PATH"

echo "1" | ./swiftly-install.sh

if ! has_command "swiftly" ; then
    test_fail "Can't find swiftly on the PATH"
fi

if [ ! -d "$HOME/.local/share/swiftly/toolchains" ]; then
    test_fail "the toolchains directory was not created in SWIFTLY_HOME_DIR"
fi

swiftly install latest

swift --version

test_pass
