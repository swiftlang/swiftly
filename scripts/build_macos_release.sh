#!/bin/bash

set -e

version="$1"

if [[ -z "$version" ]]; then
    echo "Usage: $0 <version tag>"
    exit 1
fi

buildtmp=$(mktemp -d)
swift build -c release "--build-path=$buildtmp" --arch arm64
swift build -c release "--build-path=$buildtmp" --arch x86_64

pkgtmp=$(mktemp -d)
lipo -create -output "${pkgtmp}/swiftly-init" "$buildtmp/arm64-apple-macosx/release/swiftly" "$buildtmp/x86_64-apple-macosx/release/swiftly"

if [ -z ${INSTALLER_CERT+x} ]; then
    echo "Warning: no INSTALLER_CERT is set so this will be an unsigned pkg."
else
    SIGN="--sign '${INSTALLER_CERT}'"
fi

pkgbuild --root "${pkgtmp}" \
   --install-location "usr/local/bin" \
   --version "$version" \
   --identifier "org.swift.swiftly" \
   $SIGN \
   "swiftly-$version-RELEASE-osx.pkg"
