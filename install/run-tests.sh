#!/usr/bin/env bash

# Script used to execute all the swiftly-install tests found in install/tests.
# This should be run from the install directory of the repository.
# WARNING: these tests make changes to the local filesystem and are intended to be run in a containerized environment.

source ./test-util.sh 

line_print () {
    echo "=============================================="
}

if ! has_command "curl"; then
    echo "curl must be installed in order to run the tests"
    exit 1
fi

tests_failed=0
tests_passed=0

for t in tests/*.sh; do
    line_print
    echo "Running test $t"
    echo ""
    if bash "$t"; then
        echo ""
        echo "$t PASSED"
        ((tests_passed++))
    else
        echo ""
        echo "$t FAILED"
        ((tests_failed++))
    fi
done

line_print

if [[ "$tests_failed" -gt 0 ]]; then
    echo ""
    echo "$tests_failed test(s) FAILED, $tests_passed test(s) PASSED"
    exit 1
else
    echo "All tests PASSED"
    exit 0
fi
