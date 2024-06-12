#!/usr/bin/env bash

export SWIFTLY_CPU_ARCH=$(uname -p)

swift test -Xswiftc -warnings-as-errors

# Uncomment the following lines and comment the swift test above to run the tests in the debugger
# swift build -c debug --build-tests
# lldb --one-line "settings set target.disable-aslr false" /code/.build/aarch64-unknown-linux-gnu/debug/swiftlyPackageTests.xctest
