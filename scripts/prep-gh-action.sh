#!/bin/bash

# This script does a bit of extra preparation of the docker containers used to run the GitHub workflows
# that are specific to this project's needs when building/testing. Note that this script runs on
# every supported Linux distribution so it must adapt to the distribution that it is running.

# Install the basic utilities depending on the type of Linux distribution
apt-get --help && apt-get update && TZ=Etc/UTC apt-get -y install curl make gpg tzdata
yum --help && (curl --help && yum -y install curl) && yum install make gpg

set -e

while [ $# -ne 0 ]; do
    arg="$1"
    case "$arg" in
        --install-swiftly)
            installSwiftly=true
            ;;
        --swift-main-snapshot)
            swiftMainSnapshot=true
            ;;
        *)
            ;;
    esac
    shift
done

if [ "$installSwiftly" == true ]; then
    echo "Installing swiftly"
    curl -O https://download.swift.org/swiftly/linux/swiftly-${SWIFTLY_BOOTSTRAP_VERSION}-$(uname -m).tar.gz && tar zxf swiftly-*.tar.gz && ./swiftly init -y --skip-install

    . "/root/.local/share/swiftly/env.sh"
    hash -r

    if [ -n "$GITHUB_ENV" ]; then
        echo "Updating GitHub environment"
        echo "PATH=$PATH" >> "$GITHUB_ENV" && echo "SWIFTLY_HOME_DIR=$SWIFTLY_HOME_DIR" >> "$GITHUB_ENV" && echo "SWIFTLY_BIN_DIR=$SWIFTLY_BIN_DIR" >> "$GITHUB_ENV"
    fi

    selector=()
    runSelector=()

    if [ "$swiftMainSnapshot" == true ]; then
        echo "Installing latest main-snapshot toolchain"
        selector=("main-snapshot")
        runSelector=("+main-snapshot")
    if [ -f .swift-version ]; then
        echo "Installing selected swift toolchain from .swift-version file"
        selector=()
        runSelector=()
    else
        echo "Installing latest toolchain"
        selector=("latest")
        runSelector=("+latest")
    fi

    swiftly install --post-install-file=post-install.sh "${selector[@]}"

    if [ -f post-install.sh ]; then
        echo "Performing swift toolchain post-installation"
        chmod u+x post-install.sh && ./post-install.sh
    fi

    echo "Displaying swift version"
    swift "${selector[@]} --version

    CC=clang swiftly run "${runSelector[@]}" "$(dirname "$0")/install-libarchive.sh"
else
    "$(dirname "$0")/install-libarchive.sh"
fi
