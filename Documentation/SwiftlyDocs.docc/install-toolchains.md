# Install Swift Toolchains

swiftly install

Installing a swift toolchain using swiftly involves downloading it securely and extracting it into a well-known location in your account. Here we will guide you through the different ways you can install a swift toolchain. You will need to install swiftly first. The [Getting Started](getting-started.md) guide is a good place to start with swiftly.

The easiest way to install a swift toolchain is to select the latest stable release:

```
$ swiftly install latest
```

If this is the only toolchain that is installed then swiftly will automatically "use" it so that when you run swift (or any other toolchain command) it will be this version.

```
$ swift --version

Swift version 5.8.1 (swift-5.8.1-RELEASE)
Target: x86_64-unknown-linux-gnu
```

You can be very specific about the released version that you want. We can install the 5.6.1 version like this:

```
$ swiftly install 5.6.1
```

Once you've installed more than one toolchain you may notice that swift is on the first version that you installed, not the last one. Swiftly lets you quickly switch between toolchains by "using" them. There's a swiftly subcommand for that.

```
$ swiftly use 5.6.1
```

You can also combine install and use into one command to automate this process with the `--use` switch on the install subcommand:

```
$ swiftly install --use 5.7.1
```

Sometimes you want the latest available patch of a minor release, such as 5.7. Let's omit the patch number so that we get the latest patch.

```
$ swiftly install 5.7
Installing Swift 5.7.2
```

Swiftly supports installing development snapshot toolchains. For example, you can install the latest available snapshot for the next major release using the "main-snapshot" selector and prepare your code for when it arrives.

```
$ swiftly install main-snapshot
```

If you are tracking down a problem on a specific snapshot you can download it using the date.

```
$ swiftly install main-snapshot-2022-01-28
```

The same snapshot capabilities are available for version snapshots too either the latest available one, or a specific date.

```
$ swiftly install 5.7-snapshot
$ swiftly install 5.7-snapshot-2022-08-30
```


