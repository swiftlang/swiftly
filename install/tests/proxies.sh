#!/usr/bin/env bash

# Tests that swiftly proxies relay properly to their targets
# WARNING: this test makes changes to the local filesystem and is intended to be run in a containerized environment.

set -o errexit
source ./test-util.sh

touch "$HOME/.profile"
cp "$HOME/.profile" "$HOME/.profile.bak"
prevwd=$(pwd)
wktmp=$(mktemp -d)
sitmp=$(mktemp -d)

cleanup () {
    set +o errexit

    cd "$prevwd"
    rm -rf "$sitmp"
    rm -rf "$wktmp"

    mv "$HOME/.profile.bak" "$HOME/.profile"

    if has_command "swiftly" ; then
       swiftly uninstall -y latest > /dev/null
    fi

    rm -r "$HOME/.local/share/swiftly"
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

test_log "Check swiftly proxies to 'swiftly init' when it is named swiftly-init"

swiftly=$(get_swiftly)
cp "$swiftly" "$sitmp/swiftly-init"
"$sitmp/swiftly-init" -y

. "$HOME/.local/share/swiftly/env.sh"

swiftly install 5.10.0 || echo "the install completes but exits with 1 to indicate that further action is necessary"

# The user will be told to ensure that the system deps are installed before continuing
install_system_deps

test_log "Check that the swift proxies to the toolchain version that is in use"
swift --version
swiftc --version
clang --version
clang++ --version
docc --help
sourcekit-lsp --help

test_log "Check that the version selector installs and selects the expected version"
ver571=$(swift +5.7.1 --version)
if [[ ! $ver571 == *"5.7.1"* ]]; then
    test_fail "Expected version 5.7.1 but it was $ver571"
fi

test_log "Check that the presence of .swift-version file impacts the version selected"
echo "5.7.1" > "$wktmp/.swift-version"

cd "$wktmp"
ver571=$(swift --version)
if [[ ! $ver571 == *"5.7.1"* ]]; then
    test_fail "Expected version 5.7.1 but it was $ver571"
fi

use571=$(swiftly use)
if [[ ! $use571 == *"selected by ${wktmp}/.swift-version"* ]]; then
    test_fail "Expected a selected by ${wktmp}/.swift-version indicator to show how the selection is picked"
fi

test_log "Check that 'swiftly use' updates the .swift-version file"
swiftly install 5.8.0
swiftly use 5.8.0

svf=$(cat "${wktmp}/.swift-version")
if [[ ! $svf == *"5.8.0"* ]]; then
    test_fail "Expected the ${wktmp}/.swift-version file to be updated from the use command"
fi

test_pass
