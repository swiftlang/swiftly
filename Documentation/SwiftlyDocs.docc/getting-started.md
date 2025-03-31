# Getting started with swiftly

Start using swiftly and Swift.

To get started with swiftly you can download it from [swift.org](https://swift.org/download), and extract the package.

@TabNavigator {
    @Tab("Linux") {
        If you are using Linux then you can download the binary:

        ```
        curl -L https://download.swift.org/swiftly/linux/swiftly-$(uname -m).tar.gz > swiftly.tar.gz
        tar zxf swiftly.tar.gz
        ```

        Now run swiftly init to finish the installation:

        ```
        ./swiftly init
        ```
    }

    @Tab("macOS") {
        On macOS you can either run the pkg installer from the command-line like this or run the package by double-clicking on it (not recommended):

        ```
        curl -L https://download.swift.org/swiftly/darwin/swiftly.pkg > swiftly.pkg
        installer -pkg swiftly.pkg -target CurrentUserHomeDirectory
        ```

        Once the package is installed, run `swiftly init` to finish the installation:

        ```
        ~/.swiftly/bin/swiftly init
        ```
    }
}

Swiftly installs itself and downloads the latest available Swift toolchain.
Follow the prompts for any additional steps that may be required.
Once everything is done you can begin using swift.

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

# Installing toolchains through an HTTP proxy

Swiftly downloads a list of toolchains from https://www.swift.org/ and retrieves them from CDN via https://download.swift.org.
If your environment requires a proxy, Swiftly attempts to use the standard environment variables `http_proxy`, `HTTP_PROXY`, `https_proxy` or `HTTPS_PROXY` to determine which proxy server to use instead of making a direct connection.

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
