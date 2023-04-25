#!/usr/bin/env bash

# Tests that the --disable-confirmation argument works.
# WARNING: this test makes changes to the local filesystem and is intended to be run in a containerized environment.

set -o errexit
source ./test-util.sh

cp "$HOME/.profile" "$HOME/.profile.bak"

cleanup () {
    mv "$HOME/.profile.bak" "$HOME/.profile"
    rm -r "$HOME/.local/share/swiftly"
    rm -r "$HOME/.local/bin/swiftly"
}
trap cleanup EXIT

./swiftly-install.sh -y

# .profile should be updated to update PATH.
bash --login -c "swiftly --version"

. "$HOME/.local/share/swiftly/env.sh"

if ! has_command "swiftly" ; then
    fail_test "Can't find swiftly on the PATH"
fi

DUMMY_CONTENT="should be overwritten"
echo "$DUMMY_CONTENT" > "$HOME/.local/share/swiftly/config.json"

# Running it again should overwrite the previous installation without asking us for permission.
./swiftly-install.sh --disable-confirmation

if ! has_command "swiftly" ; then
    fail_test "Can't find swiftly on the PATH"
fi

CONFIG_CONTENTS="$(cat $HOME/.local/share/swiftly/config.json)"
if [ "$CONFIG_CONTENTS" == "$DUMMY_CONTENT" ]; then
    fail_test "Config should have been overwritten after second install"
fi

test_pass
