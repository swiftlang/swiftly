#!/usr/bin/env bash

# Tests that installation can be cancelled.
# Run this from the root of the repository.
# WARNING: this test makes changes to the local filesystem and is intended to be run in a containerized environment.

set -o errexit
source ./scripts/tests/util.sh

echo "3" | ./swiftly-install.sh

if has_command "swiftly" ; then
    test_fail "swiftly executable should not have been installed"
fi

if [ ! -d "$HOME/.local/share/swiftly" ]; then
    test_fail "SWIFTLY_HOME_DIR should not have been created"
fi

test_pass
