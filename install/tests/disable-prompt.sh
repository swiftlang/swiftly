#!/usr/bin/env bash

# Tests that the --disable-confirmation argument works.
# WARNING: this test makes changes to the local filesystem and is intended to be run in a containerized environment.

set -o errexit
source ./test-util.sh

touch "$HOME/.profile"
cp "$HOME/.profile" "$HOME/.profile.bak"

cleanup () {
    mv "$HOME/.profile.bak" "$HOME/.profile"
    rm -r "$HOME/.local/share/swiftly"
    rm -r "$HOME/.local/bin/swiftly"
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

$(get_swiftly) -y list

# .profile should be updated to update PATH.
bash --login -c "swiftly --version"

. "$HOME/.local/share/swiftly/env.sh"

if ! has_command "swiftly" ; then
    test_fail "Can't find swiftly on the PATH"
fi

test_pass
