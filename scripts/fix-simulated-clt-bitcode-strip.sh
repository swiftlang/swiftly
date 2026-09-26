#!/bin/bash

# When swiftly is configured with a custom SWIFTLY_HOME_DIR on macOS, it creates a
# minimal simulated CommandLineTools directory so that xcrun/DEVELOPER_DIR can find
# the selected toolchain (see the SWIFTLY_TOOLCHAINS_DIR handling in
# Sources/MacOSPlatform/MacOS.swift). That directory intentionally contains almost
# none of the real command line tools' usr/bin contents.
#
# swift-build (used by `swift build`/`swift test`) looks for a tool named
# bitcode_strip in each configured toolchain's search paths whenever it needs to
# strip bitcode while copying Swift libraries into a test bundle. Since the
# simulated CommandLineTools directory doesn't have it, the build fails with:
#
#   error: Passed --strip-bitcode without --strip-bitcode-tool.
#
# This script symlinks bitcode_strip from the real, system-installed command line
# tools into swiftly's simulated CommandLineTools directory so that swift-build can
# find it.

set -e

swiftlyHomeDir="$1"

if [ -z "$swiftlyHomeDir" ]; then
    echo "Usage: $0 <swiftly-home-dir>"
    exit 1
fi

realBitcodeStrip="/Library/Developer/CommandLineTools/usr/bin/bitcode_strip"

if [ ! -f "$realBitcodeStrip" ]; then
    echo "Warning: $realBitcodeStrip not found, skipping bitcode_strip workaround for simulated CommandLineTools directory"
    exit 0
fi

simulatedCltBinDir="$swiftlyHomeDir/CommandLineTools/usr/bin"
mkdir -p "$simulatedCltBinDir"
ln -sf "$realBitcodeStrip" "$simulatedCltBinDir/bitcode_strip"
