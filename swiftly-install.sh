#!/usr/bin/env bash

# Script used to install and configure swiftly.
# 
# If successful, this will create a directory at $SWIFTLY_HOME_DIR (default
# $XDG_DATA_HOME/swiftly, if XDG_DATA_HOME isn't set, then ~/.local/share/swiftly)
# containing a config.json file with platform information. It will also download
# and install a swiftly executable at $SWIFTLY_HOME_DIR (default ~/.local/bin).
#
# curl is required to run this script.

set -o errexit

has_command () {
    command -v "$1" > /dev/null
}

DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"
HOME_DIR="${SWIFTLY_HOME_DIR:-$DATA_DIR/swiftly}"
BIN_DIR="${SWIFTLY_BIN_DIR:-$HOME/.local/bin}"

if ! has_command "curl" ; then
    echo "Error: curl must be installed to download swiftly"
    exit 1
fi

if [ -f "/etc/os-release" ]; then
    OS_RELEASE="/etc/os-release"
elif [ -f "/usr/lib/os-release" ]; then
    OS_RELEASE="/usr/lib/os-release"
else
    echo "Error: could not detect OS information"
    exit 1
fi

source "$OS_RELEASE"

case "$ID" in
    "amzn")
        if [ "VERSION_ID" -ne "2" ]; then
            echo "Error: Unsupported Amazon Linux version: $PRETTY_NAME"
            exit 1
        fi
        PLATFORM_NAME="amazonlinux2"
        PLATFORM_NAME_FULL="amazonlinux2"
        ;;

    "ubuntu")
        case "$UBUNTU_CODENAME" in
            "jammy")
                PLATFORM_NAME="ubuntu2204"
                PLATFORM_NAME_FULL="ubuntu22.04"
                ;;

            "focal")
                PLATFORM_NAME="ubuntu2004"
                PLATFORM_NAME_FULL="ubuntu20.04"
                ;;

            "bionic")
                PLATFORM_NAME="ubuntu1804"
                PLATFORM_NAME_FULL="ubuntu18.04"
                ;;

            *)
                echo "Error: Unsupported Ubuntu version: $PRETTY_NAME"
                exit 1
                ;;
        esac
        ;;

    *)
        echo "Error: Unsupported platform: $PRETTY_NAME"
        exit 1
        ;;
esac

RAW_ARCH="$(uname -m)"
case "$RAW_ARCH" in
    "x86_64")
        ARCH="x86_64"
        PLATFORM_ARCH="null"
        ;;

    "aarch64" | "arm64")
        ARCH="aarch64"
        PLATFORM_ARCH='"aarch64"'
        ;;

    *)
        echo "Error: Unsupported CPU architecture: $RAW_ARCH"
        ;;
esac

JSON_OUT=$(cat <<EOF
{
  "platform": {
    "name": "$PLATFORM_NAME",
    "nameFull": "$PLATFORM_NAME_FULL",
    "namePretty": "$PRETTY_NAME",
    "architecture": $PLATFORM_ARCH
  },
  "installedToolchains": []
  "inUse": null,
}
EOF
)

mkdir -p $HOME_DIR

EXECUTABLE_NAME="swiftly-$ARCH-unknown-linux-gnu"
echo "Downloading swiftly..."
curl \
    --header "Authorization: Bearer $SWIFTLY_GITHUB_TOKEN" \
    "https://github.com/patrickfreed/swiftly/releases/latest/download/$EXECUTABLE_NAME" \
    --output "$BIN_DIR/swiftly"

echo "$JSON_OUT" > "$HOME_DIR/config.json"

echo "swiftly has been succesfully installed!"
if ! has_command "swiftly" ; then
    echo "You may have to restart your shell in order for swiftly to be accessible from your $PATH"
fi
