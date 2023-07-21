#!/usr/bin/env bash

# Tests that .zprofile is updated properly if the user's shell is zsh.
# WARNING: this test makes changes to the local filesystem and is intended to be run in a containerized environment.

set -o errexit
source ./test-util.sh

cleanup () {
    set +o errexit

    if [[ -f "$HOME/.bash_profile" ]]; then
        rm "$HOME/.bash_profile"
    fi
    rm "$HOME/.bash_login"

    rm -r "$HOME/.local/share/swiftly"
    rm "$HOME/.local/bin/swiftly"
}
trap cleanup EXIT

touch "$HOME/.bash_profile"
touch "$HOME/.bash_login"
export SHELL="bash"

echo "1" | ./swiftly-install.sh --no-install-system-deps

if [[ ! "$(cat $HOME/.bash_profile)" =~ "swiftly/env.sh" ]]; then
   test_fail "install did not update .bash_profile"
fi

if [[ "$(cat $HOME/.bash_login)" != "" ]]; then
   test_fail "install updated .bash_login when .bash_profile existed"
fi

rm "$HOME/.bash_profile"
printf "1\ny\n" | ./swiftly-install.sh --no-install-system-deps

if [[ -f "$HOME/.bash_profile" ]]; then
   test_fail "install created .bash_profile when it should not have"
fi

if [[ ! "$(cat $HOME/.bash_login)" =~ "swiftly/env.sh" ]]; then
   test_fail "install did not update .bash_login"
fi

test_pass
