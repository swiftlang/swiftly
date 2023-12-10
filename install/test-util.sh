#!/usr/bin/env bash

# Common utility functionality used in the various bash tests for swiftly-install.sh.

export SWIFTLY_READ_FROM_STDIN=1

test_log () {
    echo "==========================="
    echo "$1"
    echo "==========================="
}

has_command () {
    command -v "$1" > /dev/null
}

test_name () {
    basename "$0"
}

test_fail () {
    if [ ! -z "$1" ]; then
        printf "$1\n"
    fi

    if [ ! -z "$3" ]; then
        printf "actual: $2\n"
        printf "expected: $3\n"
    fi
    echo ""
    echo "$(test_name) FAILED"
    exit 1
}

test_pass () {
    echo ""
    echo "$(test_name) PASSED"
    exit 0
}

get_os () {
    if [[ -f "/etc/os-release" ]]; then
        OS_RELEASE="/etc/os-release"
    elif [[ -f "/usr/lib/os-release" ]]; then
        OS_RELEASE="/usr/lib/os-release"
    else
        echo "Error: could not detect OS information"
        exit 1
    fi

    source "$OS_RELEASE"

    case "$ID" in
        "amzn")
            echo "amazonlinux2"
            ;;

        "ubuntu")
            case "$UBUNTU_CODENAME" in
                "jammy")
                    echo "ubuntu2204"
                    ;;

                "focal")
                    echo "ubuntu2004"
                    ;;

                "bionic")
                    echo "ubuntu1804"
                    ;;

                *)
                    echo "Unsupported Ubuntu version: $PRETTY_NAME"
                    exit 1
                    ;;
            esac
            ;;

        "rhel")
            echo "rhel-ubi9"
            ;;

        *)
            echo "Unsupported platform: $PRETTY_NAME"
            exit 1
            ;;
    esac
}
