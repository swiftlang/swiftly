#!/usr/bin/env bash

export SWIFTLY_CPU_ARCH=$(uname -p)

swift test -Xswiftc -warnings-as-errors
