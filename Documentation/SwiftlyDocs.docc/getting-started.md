# Getting Started with Swiftly

To download swiftly and install Swift, run the following in your terminal, then follow the on-screen instructions:

```
curl -L https://swiftlang.github.io/swiftly/swiftly-install.sh | bash
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
```

Or, you can install (and use) a swift release:

```
$ swiftly install --use 5.7

$ swift --version

Swift version 5.7.2 (swift-5.7.2-RELEASE)
Target: x86_64-unknown-linux-gnu
```

There's also an option to install the latest snapshot release and get access to the latest features:

```
$ swiftly install main-snapshot
```

> Note: This last example just installed the toolchain. You can run "swiftly use" to switch to it and other installed toolchahins when you're ready.
