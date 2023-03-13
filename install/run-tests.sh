#!/usr/bin/env bash

# Common utility functionality used in the various bash tests for swiftly-install.sh.

TEST
for t in tests/*.sh; do
    bash "$t"
