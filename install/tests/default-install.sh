#!/usr/bin/env bash

# Tests that an unconfigured installation works properly.
# WARNING: this test makes changes to the local filesystem and is intended to be run in a containerized environment.

set -o errexit
source ./test-util.sh

cp "$HOME/.profile" "$HOME/.profile.bak"

cleanup () {
    set +o errexit

    mv "$HOME/.profile.bak" "$HOME/.profile"

    if has_command "swiftly" ; then
       swiftly uninstall -y latest > /dev/null
    fi

    rm -r "$HOME/.local/share/swiftly"
    rm "$HOME/.local/bin/swiftly"
}
trap cleanup EXIT

if has_command apt-get ; then
    apt-get remove -y zlib1g-dev
elif has_command yum ; then
    yum remove -y libcurl-devel
fi

printf "1\ny\n" | DEBIAN_FRONTEND="noninteractive" ./swiftly-install.sh

# .profile should be updated to update PATH.
bash --login -c "swiftly --version"

. "$HOME/.local/share/swiftly/env.sh"

if ! has_command "swiftly" ; then
    test_fail "Can't find swiftly on the PATH"
fi

if [[ ! -d "$HOME/.local/share/swiftly/toolchains" ]]; then
    test_fail "the toolchains directory was not created in SWIFTLY_HOME_DIR"
fi

if has_command dpkg ; then
    if ! dpkg --status zlib1g-dev ; then
        test_fail "System dependencies were not installed properly"
    fi
elif has_command rpm ; then
    if ! rpm -q libcurl-devel ; then
        test_fail "System dependencies were not installed properly"
    fi
fi

swiftly install latest

swift --version

test_pass
