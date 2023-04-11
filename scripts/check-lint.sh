#!/usr/bin/env bash

set -o errexit

swiftformat --lint --dryrun .
