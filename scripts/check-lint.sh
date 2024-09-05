#!/usr/bin/env bash

set -o errexit

swift run swiftformat --lint --dryrun .
