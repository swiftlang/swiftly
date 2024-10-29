# Getting Started with Swiftly

Start using swiftly and swift.

To get started with swiftly you can download it from [swift.org](https://swift.org/download), and extract the package.

@TabNavigator {
    @Tab("Linux") {
        If you are using Linux then you can verify and extract the archive like this:

        ```
        sha256sum swiftly-x.y.z.tar.gz # Check that the hash matches what's reported on swift.org
        tar zxf swiftly-x.y.z.tar.gz
        ```

        Now run swiftly init to finish the installation:

        ```
        ./swiftly init
        ```
    }

    @Tab("macOS") {
        On macOS you can either run the pkg installer from the command-line like this or just run the package by double-clicking on it (not recommended):

        ```
        installer -pkg swift-x.y.z.pkg -target CurrentUserHomeDirectory
        ```

        Now run swiftly init to finish the installation:

        ```
        $HOME/usr/local/bin/swiftly init
        ```
    }
}

Swiftly will install itself and download the latest available Swift toolchain. Follow the prompts for any additional steps. Once everything is done you can begin using swift.

```
$ swift --version

Swift version 6.0.1 (swift-6.0.1-RELEASE)
Target: x86_64-unknown-linux-gnu

$ swift build    # Build your package with the latest toolchain
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
