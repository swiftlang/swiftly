#!/usr/bin/env bash

set -o errexit

CONFIGURATION="${SWIFTLY_CONFIGURATION:-debug}"

swift build \
      --static-swift-stdlib \
      --configuration "$CONFIGURATION" \

mv ./.build/release/swiftly $1
