#!/usr/bin/env bash

# Tests that a platform can be manually specified via the --platform option.
# WARNING: this test makes changes to the local filesystem and is intended to be run in a containerized environment.

set -o errexit
source ./test-util.sh

cleanup () {
    set +o errexit
}
trap cleanup EXIT

platforms=("ubuntu22.04" "ubuntu20.04" "ubuntu18.04" "amazonlinux2" "rhel9")

# Swiftly needs these things at a minimum and will abort telling the user
#  if they are missing.
if has_command apt-get ; then
    apt-get update
    apt-get install -y ca-certificates gpg # These are needed for swiftly
elif has_command yum ; then
    yum install -y ca-certificates gpg # These are needed for swiftly to function
fi

for platform in "${platforms[@]}"; do
    echo "Performing installation with platform $platform..."
    $(get_swiftly) --overwrite -y --platform "$platform" list
    cat $HOME/.local/share/swiftly/config.json

    if [[ "$platform" == "rhel9" ]]; then
        platform="ubi9"
    fi

    if ! grep -q "\"nameFull\" : \"$platform\"" "$HOME/.local/share/swiftly/config.json" ; then
        test_fail "platform option had no effect for platform \"$platform\""
    fi

    rm -rf $HOME/.local/share/swiftly
    rm -rf $HOME/.local/bin/swiftly
done

test_pass
