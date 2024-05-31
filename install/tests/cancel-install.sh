#!/usr/bin/env bash

# Tests that installation can be cancelled.
# WARNING: this test makes changes to the local filesystem and is intended to be run in a containerized environment.

set -o errexit
source ./test-util.sh

# Swiftly needs these things at a minimum and will abort telling the user
#  if they are missing.
if has_command apt-get ; then
    apt-get update
    apt-get install -y ca-certificates gpg # These are needed for swiftly
elif has_command yum ; then
    yum install -y ca-certificates gpg # These are needed for swiftly to function
fi

echo "0" | $(get_swiftly) init || echo 'Swiftly exited'

if has_command "swiftly" ; then
    test_fail "swiftly executable should not have been installed"
fi

if [[ -d "$HOME/.local/share/swiftly" ]]; then
    test_fail "SWIFTLY_HOME_DIR should not have been created"
fi

test_pass
