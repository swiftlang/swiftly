#!/usr/bin/env bash

set -o errexit

swift build \
      --static-swift-stdlib \
      --configuration release

mv ./.build/release/swiftly $1
