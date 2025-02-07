# Getting Started with Swiftly

Start using swiftly and swift.

To get started with swiftly you can download it from [swift.org](https://swift.org/download), and extract the package.

@TabNavigator {
    @Tab("Linux") {
        If you are using Linux then you can verify and extract the archive like this:

        ```
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
        ~/usr/local/bin/swiftly init
        ```
    }
}

Swiftly will install itself and download the latest available Swift toolchain. Follow the prompts for any additional steps. Once everything is done you can begin using swift.

```
$ swift --version

Swift version 6.0.3 (swift-6.0.3-RELEASE)
...

$ swift build        # Build with the latest (6.0.3) toolchain
```

You can install (and use) another release toolchain:

```
$ swiftly install --use 5.10

$ swift --version

Swift version 5.10.1 (swift-5.10.1-RELEASE)
...

$ swift build    # Build with the 5.10.1 toolchain
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

# Proxy

Swiftly downloads a list of toolchains from https://www.swift.org/ and retrieves them from CDN via https://download.swift.org.
If your environment requires a proxy, Swiftly will attempt to use the standard environment variables `http_proxy`, `HTTP_PROXY`, `https_proxy` or `HTTPS_PROXY` to determine which proxy server to use instead of making a direct connection.

To download latest nightly snapshot using a proxy:
```
$ export https_proxy=http://proxy:3128
$ swiftly install main-snapshot
```

# See Also:

- [Install Toolchains](install-toolchains)
- [Using Toolchains](use-toolchains)
- [Uninstall Toolchains](uninstall-toolchains)
- [Swiftly CLI Reference](swiftly-cli-reference)
