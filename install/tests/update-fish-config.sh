#!/usr/bin/env bash

# Tests that swiftly.fish is updated properly if the user's shell is fish.
# WARNING: this test makes changes to the local filesystem and is intended to be run in a containerized environment.

set -o errexit
source ./test-util.sh

cleanup () {
    set +o errexit

    rm "$HOME/.config/fish/conf.d/swiftly.fish"
    rm "$HOME/.xdg/config/fish/conf.d/swiftly.fish"

    rm -r "$HOME/.local/share/swiftly"
    rm "$HOME/.local/bin/swiftly"
}
trap cleanup EXIT

export SHELL="fish"

mkdir -p "$HOME/.config/fish/conf.d"
echo "1" | ./swiftly-install.sh --no-install-system-deps

if [[ ! "$(cat $HOME/.config/fish/conf.d/swiftly.fish)" =~ "swiftly/env.fish" ]]; then
   test_fail "install did not update ~/.config/fish/conf.d/swiftly.fish"
fi

export XDG_CONFIG_HOME="$HOME/.xdg/config"
mkdir -p "$XDG_CONFIG_HOME/fish/conf.d"
./swiftly-install.sh -y --overwrite --no-install-system-deps

if [[ ! "$(cat $XDG_CONFIG_HOME/fish/conf.d/swiftly.fish)" =~ "swiftly/env.fish" ]]; then
   test_fail "install did not update \$XDG_CONFIG_HOME/fish/conf.d/swiftly.fish"
fi


test_pass
