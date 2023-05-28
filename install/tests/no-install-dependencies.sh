#!/usr/bin/env bash

# Tests passing --no-install-system-deps disables installing system dependencies.
# Also verifies that interactive customization also does cancels them.
# WARNING: this test makes changes to the local filesystem and is intended to be run in a containerized environment.

set -o errexit
source ./test-util.sh

cleanup () {
    set +o errexit

    rm -r "$HOME/.local/share/swiftly"
    rm "$HOME/.local/bin/swiftly"
}
trap cleanup EXIT

verify_dependencies_not_installed () {
    if has_command dpkg ; then
        if dpkg --status zlib1g-dev ; then
            test_fail "System dependencies were installed when they shouldn't have been"
        fi
    elif has_command rpm ; then
        if rpm -q libcurl-devel ; then
            test_fail "System dependencies were installed when they shouldn't have been"
        fi
    fi
}

if has_command apt-get ; then
    apt-get remove -y zlib1g-dev
elif has_command yum ; then
    yum remove -y libcurl-devel
fi

echo "1" | ./swiftly-install.sh --no-install-system-deps

verify_dependencies_not_installed

# Use all defaults except "n" for system dependency installation.
printf "2\n\n\n\nn\n1\ny\n" | ./swiftly-install.sh

verify_dependencies_not_installed

test_pass
