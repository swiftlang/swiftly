#!/usr/bin/env bash

# Tests that swiftly.fish is updated properly if the user's shell is fish.
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

    rm "$HOME/.config/fish/conf.d/swiftly.fish"
    rm "$HOME/.xdg/config/fish/conf.d/swiftly.fish"

    rm -r "$HOME/.local/share/swiftly"

    chsh --shell "$oldshell"

    # Disable password prompts when trying to change the shell
    sed s/sufficient/required/g -i /etc/pam.d/chsh || echo "Failed to disable password prompts in chsh"
}
trap cleanup EXIT

if has_command apt-get ; then
    apt-get update
    apt-get install -y fish
elif has_command yum ; then
    if yum install -y fish; then
        echo "fish shell is installed"
    else
        echo "skipping test since we can't install the fish shell"
        exit 0
    fi
fi

chsh --shell "/bin/fish"

mkdir -p "$HOME/.config/fish/conf.d"

# Swiftly needs these things at a minimum and will abort telling the user
#  if they are missing.
if has_command apt-get ; then
    apt-get update
    apt-get install -y ca-certificates gpg # These are needed for swiftly
elif has_command yum ; then
    yum install -y ca-certificates gpg # These are needed for swiftly to function
fi

echo "1" | $(get_swiftly) init

if [[ ! "$(cat $HOME/.config/fish/conf.d/swiftly.fish)" =~ "swiftly/env.fish" ]]; then
   test_fail "install did not update ~/.config/fish/conf.d/swiftly.fish"
fi

export XDG_CONFIG_HOME="$HOME/.xdg/config"
mkdir -p "$XDG_CONFIG_HOME/fish/conf.d"
$(get_swiftly) -y init --overwrite

if [[ ! "$(cat $XDG_CONFIG_HOME/fish/conf.d/swiftly.fish)" =~ "swiftly/env.fish" ]]; then
   test_fail "install did not update \$XDG_CONFIG_HOME/fish/conf.d/swiftly.fish"
fi

test_pass
