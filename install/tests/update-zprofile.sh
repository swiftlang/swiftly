#!/usr/bin/env bash

# Tests that .zprofile is updated properly if the user's shell is zsh.
# WARNING: this test makes changes to the local filesystem and is intended to be run in a containerized environment.

set -o errexit
source ./test-util.sh

cleanup () {
    set +o errexit

    rm "$HOME/.zprofile"

    rm -r "$HOME/.local/share/swiftly"
    rm "$HOME/.local/bin/swiftly"
}
trap cleanup EXIT

touch "$HOME/.zprofile"
export SHELL="zsh"

echo "1" | ./swiftly-install.sh

if [[ ! "$(cat $HOME/.zprofile)" =~ "swiftly/env.sh" ]]; then
   test_fail "install did not update .zprofile"
fi

test_pass
