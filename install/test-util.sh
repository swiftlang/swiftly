#!/usr/bin/env bash

# Common utility functionality used in the various bash tests for swiftly-install.sh.

has_command () {
    command -v "$1" > /dev/null
}

test_fail () {
    if [ ! -z "$1" ]; then
        printf "$1\n"
    fi

    if [ ! -z "$3" ]; then
        printf "actual: $2\n"
        printf "expected: $3\n"
    fi
    exit 1
}

test_pass () {
    exit 0
}
