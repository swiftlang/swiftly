# Getting Started with Swiftly

To download swiftly and install Swift, run the following in your terminal, then follow the on-screen instructions:

```
curl -L https://swiftlang.github.io/swiftly/swiftly-install.sh | bash
```

Alternatively, you can download the swiftly binary and install itself like this:

```
swiftly init
```

Once swiftly is installed you can use it to install the latest available swift toolchain like this:

```
$ swiftly install latest

Fetching the latest stable Swift release...
Installing Swift 5.8.1
Downloaded 488.5 MiB of 488.5 MiB
Extracting toolchain...
Swift 5.8.1 installed successfully!

$ swift --version

Swift version 5.8.1 (swift-5.8.1-RELEASE)
Target: x86_64-unknown-linux-gnu

$ swift build    # Build with the latest (5.8.1) toolchain
```

You can install (and use) another release toolchain:

```
$ swiftly install --use 5.7

$ swift --version

Swift version 5.7.2 (swift-5.7.2-RELEASE)
Target: x86_64-unknown-linux-gnu

$ swift build    # Build with the 5.7.2 toolchain
```

Quickly test your package with the latest nightly snapshot to prepare for the next release:

```
$ swiftly install main-snapshot
$ swiftly run swift test +main-snapshot   # Run "swift test" with the main-snapshot toolchain
$ swift build                             # Continue to build with my usual toolchain
```

Uninstall this toolchain after you're finished with it:

```
$ swiftly uninstall main-snapshot
```

# See Also:

- [Install Toolchains](install-toolchains)
- [Using Toolchains](use-toolchains)
- [Uninstall Toolchains](uninstall-toolchains)
- [Swiftly CLI Reference](swiftly-cli-reference)
