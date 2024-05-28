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

# Disable password prompts when trying to change the shell
sed s/required/sufficient/g -i /etc/pam.d/chsh || echo "Failed to disable password prompts in chsh"

cleanup () {
    set +o errexit

    rm "$HOME/.zprofile"

    rm -r "$HOME/.local/share/swiftly"
    rm "$HOME/.local/bin/swiftly"

    chsh --shell "$oldshell"

    sed s/sufficient/required/g -i /etc/pam.d/chsh || echo "Failed to restore password prompts in chsh"
}
trap cleanup EXIT

if has_command apt-get ; then
    apt-get update
    apt-get install -y zsh
elif has_command yum ; then
    yum install -y zsh
fi

chsh --shell "/bin/zsh"

mkdir -p "$HOME/.config/fish/conf.d"

# Swiftly needs these things at a minimum and will abort telling the user
#  if they are missing.
if has_command apt-get ; then
    apt-get update
    apt-get install -y ca-certificates gpg # These are needed for swiftly
elif has_command yum ; then
    yum install -y ca-certificates gpg # These are needed for swiftly to function
fi

touch "$HOME/.zprofile"
chsh --shell "/bin/zsh"

echo "1" | $(get_swiftly) list

if [[ ! "$(cat $HOME/.zprofile)" =~ "swiftly/env.sh" ]]; then
   test_fail "install did not update .zprofile"
fi

test_pass
