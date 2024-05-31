#!/usr/bin/env bash

# Common utility functionality used in the various bash tests for installing the swiftly installation

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

get_swiftly () {
    if [[ -f "../.build/$(uname -m)-unknown-linux-gnu/release/swiftly" ]]; then
        echo "../.build/$(uname -m)-unknown-linux-gnu/release/swiftly"
    else
        echo "Error: cannot find the swiftly binary. Try building it first with 'swift build -c release --static-swift-stdlib'"
        exit 1
    fi
}

install_system_deps() {
    # Keep this list in sync with the hardcoded metadata in Sources/Swiftly/Install.swift
    case "$(get_os)" in
        "ubuntu1804")
            system_deps=(binutils
                         git
                         libc6-dev
                         libcurl4-openssl-dev
                         libedit2
                         libgcc-5-dev
                         libpython3.6
                         libstdc++-5-dev
                         libxml2-dev
                         pkg-config
                         tzdata
                         zip
                         zlib1g-dev)
            ;;

        "ubuntu2004")
            system_deps=(binutils
                         git
                         gnupg2
                         libc6-dev
                         libcurl4-openssl-dev
                         libedit2
                         libgcc-9-dev
                         libpython3.8
                         libstdc++-9-dev
                         libxml2-dev
                         libz3-dev
                         pkg-config
                         tzdata
                         zip
                         zlib1g-dev)
            ;;

        "ubuntu2204")
            system_deps=(binutils
                         git
                         gnupg2
                         unzip
                         libc6-dev
                         libcurl4-openssl-dev
                         libedit2
                         libgcc-11-dev
                         libpython3-dev
                         libstdc++-11-dev
                         libxml2-dev
                         libz3-dev
                         pkg-config
                         python3-lldb-13
                         tzdata
                         zip
                         zlib1g-dev)
            ;;

        "amazonlinux2")
            system_deps=(binutils
                         gcc
                         git
                         glibc-static
                         libcurl-devel
                         libedit
                         libicu
                         libxml2-devel
                         tar
                         unzip
                         zip
                         zlib-devel)
            ;;

        "rhel-ubi9")
            system_deps=(git
                         gcc-c++
                         libcurl-devel
                         libedit-devel
                         libuuid-devel
                         libxml2-devel
                         ncurses-devel
                         python3-devel
                         rsync
                         sqlite-devel
                         unzip
                         zip)
            ;;

        *)
            echo "Unrecognized platform"
            exit 1
            ;;
    esac

    if has_command apt-get ; then
        apt-get update
        TZ=Etc/UTC DEBIAN_FRONTEND=noninteractive apt-get install -y "${system_deps[@]}"
    elif has_command yum ; then
        yum install -y "${system_deps[@]}"
    fi
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
