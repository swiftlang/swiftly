#!/usr/bin/env bash

# Tests that a platform can be manually specified via the --platform option.
# WARNING: this test makes changes to the local filesystem and is intended to be run in a containerized environment.

set -o errexit
source ./test-util.sh

cleanup () {
    set +o errexit

    rm -r "$HOME/.local/share/swiftly"
    rm "$HOME/.local/bin/swiftly"
}
trap cleanup EXIT

platforms=("ubuntu22.04" "ubuntu20.04" "ubuntu18.04" "amazonlinux2" "rhel9")

for platform in "${platforms[@]}"; do
    ./swiftly-install.sh --overwrite --disable-confirmation --no-install-system-deps --platform "$platform"
    cat $HOME/.local/share/swiftly/config.json

    if [[ "$platform" == "rhel9" ]]; then
        platform="ubi9"
    fi

    if ! grep -q "\"nameFull\": \"$platform\"" "$HOME/.local/share/swiftly/config.json" ; then
        test_fail "platform option had no effect for platform \"$platform\""
    fi
done

test_pass
