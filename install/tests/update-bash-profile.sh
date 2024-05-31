#!/usr/bin/env bash

# Tests that .zprofile is updated properly if the user's shell is zsh.
# WARNING: this test makes changes to the local filesystem and is intended to be run in a containerized environment.

set -o errexit
source ./test-util.sh

oldshell="$SHELL"

# We need to be able to change the login shell on default RHEL
if has_command yum ; then
    yum install -y util-linux-user
fi

cleanup () {
    set +o errexit

    if [[ -f "$HOME/.bash_profile" ]]; then
        rm "$HOME/.bash_profile"
    fi
    rm "$HOME/.bash_login"

    rm -r "$HOME/.local/share/swiftly"

    chsh --shell "$oldshell"
}
trap cleanup EXIT

touch "$HOME/.bash_profile"
touch "$HOME/.bash_login"

# Change the user's login shell to bash for the session of this script
chsh --shell /bin/bash

# Swiftly needs these things at a minimum and will abort telling the user
#  if they are missing.
if has_command apt-get ; then
    apt-get update
    apt-get install -y ca-certificates gpg # These are needed for swiftly
elif has_command yum ; then
    yum install -y ca-certificates gpg # These are needed for swiftly to function
fi

echo "1" | $(get_swiftly) init

if [[ ! "$(cat $HOME/.bash_profile)" =~ "swiftly/env.sh" ]]; then
   test_fail "install did not update .bash_profile"
fi

if [[ "$(cat $HOME/.bash_login)" != "" ]]; then
   test_fail "install updated .bash_login when .bash_profile existed"
fi

rm "$HOME/.bash_profile"
$(get_swiftly) init -y --overwrite

if [[ -f "$HOME/.bash_profile" ]]; then
   test_fail "install created .bash_profile when it should not have"
fi

if [[ ! "$(cat $HOME/.bash_login)" =~ "swiftly/env.sh" ]]; then
   test_fail "install did not update .bash_login"
fi

test_pass
