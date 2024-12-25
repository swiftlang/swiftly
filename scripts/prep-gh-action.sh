#!/bin/bash

# Install the basic utilities depending on the type of Linux distribution
apt-get --help && apt-get update && TZ=Etc/UTC apt-get -y install curl make gpg tzdata
yum --help && (curl --help && yum -y install curl) && yum install make gpg

set -e

while [ $# -ne 0 ]
do
    arg="$1"
    case "$arg" in
        --install-swiftly)
            installSwiftly=true
            ;;
        *)
            ;;
    esac
    shift
done

if [ "$installSwiftly" == true ]; then
    echo "Installing swiftly"
    curl -O https://download.swift.org/swiftly/linux/swiftly-${SWIFTLY_BOOTSTRAP_VERSION}-$(uname -m).tar.gz && tar zxf swiftly-*.tar.gz && ./swiftly init -y --skip-install

    echo "Updating environment"
    . "/root/.local/share/swiftly/env.sh" && echo "PATH=$PATH" >> "$GITHUB_ENV" && echo "SWIFTLY_HOME_DIR=$SWIFTLY_HOME_DIR" >> "$GITHUB_ENV" && echo "SWIFTLY_BIN_DIR=$SWIFTLY_BIN_DIR" >> "$GITHUB_ENV"'

    echo "Installing selected swift toolchain"
    swiftly install --post-install-file=post-install.sh

    echo "Performing swift toolchain post-installation"
    chmod u+x post-install.sh && ./post-install.sh

    echo "Displaying swift version"
    swift --version

    CC=clang swiftly run "$(dirname "$0")/install-libarchive.sh"
else
    # Official swift docker images are missing these packages at the moment
    (cat /etc/os-release | grep bookworm) && apt-get -y install libstdc++-12-dev gnupg2
    (cat /etc/os-release | grep 'Fedora Linux 39') && yum -y install libstdc++-devel libstdc++-static

    "$(dirname "$0")/install-libarchive.sh"
fi
