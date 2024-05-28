#!/bin/bash

# Run each test in a fresh docker image to ensure that no test relies on
# the previous state left over from the previous test. This helps to
# improve the reliability of each test case and the ability to run them
# in isolation if there is a failure.

# First argument is the docker image name to use for the tests, such as
#  ubuntu:22.04

pushd "$(dirname $0)"

for i in tests/*.sh; do
    docker run --rm -v $(dirname $(pwd)):/swiftly "$1" bash -c "cd /swiftly/install; ./$i" || exit 1
done

popd
