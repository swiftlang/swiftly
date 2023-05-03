#!/usr/bin/env bash

# Tests that an unconfigured installation works properly.
# WARNING: this test makes changes to the local filesystem and is intended to be run in a containerized environment.

set -o errexit
source ./test-util.sh

cp "$HOME/.profile" "$HOME/.profile.bak"

cleanup () {
    set +o errexit

    mv "$HOME/.profile.bak" "$HOME/.profile"

    if has_command "swiftly" ; then
       swiftly uninstall -y latest > /dev/null
    fi

    rm -r "$HOME/.local/share/swiftly"
    rm "$HOME/.local/bin/swiftly"
}
trap cleanup EXIT

echo "1" | ./swiftly-install.sh

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

swift --version

test_pass
