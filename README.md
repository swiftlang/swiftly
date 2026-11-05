# swiftly

swiftly is a CLI tool for installing, managing, and switching between [Swift](https://www.swift.org/) toolchains, written in Swift. swiftly itself is designed to be extremely easy to install and get running, and its command interface is intended to be flexible while also being simple to use. You can use it with Linux and macOS.

### Installation and Basic Usage

⚠️ Installation has changed from the 0.3.0 release. See [Upgrade from previous](#upgrade-from-previous) below for notes on upgrading from older releases.

Install swiftly by going to the [Swift Install Page](https://swift.org/install) of swift.org and following the instructions there.

Once swiftly is installed it will automatically install the latest released toolchain. You can use the familiar toolchain commands right away:

```
swift --version
--
Swift version 6.0.3 (swift-6.0.3-RELEASE)
Target: x86_64-unknown-linux-gnu
```

```
lldb
--
(lldb): _
```

Install another toolchain, such as the latest nightly snapshot of the main branch. Use it so that when you run a toolchain command it uses that one.

```
swiftly install main-snapshot
swiftly use main-snapshot
swift --version
--
Apple Swift version 6.2-dev (LLVM 059105ceb0cb60e, Swift 714c862d3791544)
Target: arm64-apple-macosx15.0
Build config: +assertions
```

For more detailed usage guides there is [documentation](https://swiftpackageindex.com/swiftlang/swiftly/main/documentation/swiftlydocs).

## Features

- [Installing multiple toolchains](https://swiftpackageindex.com/swiftlang/swiftly/main/documentation/swiftlydocs/install-toolchains), including both stable releases and snapshots
- [Switching which installed toolchain is active](https://swiftpackageindex.com/swiftlang/swiftly/main/documentation/swiftlydocs/use-toolchains) (i.e. which one is discovered via `$PATH`)
- [Updating installed toolchains](https://swiftpackageindex.com/swiftlang/swiftly/main/documentation/swiftlydocs/update-toolchain) to the latest available versions of those toolchains
- [Uninstalling installed toolchains](https://swiftpackageindex.com/swiftlang/swiftly/main/documentation/swiftlydocs/uninstall-toolchains)
- Listing the toolchains that are available to install with the [list-available](https://swiftpackageindex.com/swiftlang/swiftly/main/documentation/swiftlydocs/swiftly-cli-reference#list-available) subcommand
- Sharing the preferred toolchain as a project setting with a [.swift-version](https://swiftpackageindex.com/swiftlang/swiftly/main/documentation/swiftlydocs/use-toolchains#Sharing-recommended-toolchain-versions) file
- Running a single command on a particular toolchain with the [run](https://swiftpackageindex.com/swiftlang/swiftly/main/documentation/swiftlydocs/swiftly-cli-reference#run) subcommand

## Platform support

swiftly is supported on Linux and macOS, and can automatically configure shell profiles for Bash, Z shell, Fish, Murex, and Nushell. For more detailed information about swiftly's intended features and implementation, check out the [design document](DESIGN.md).

## Updating swiftly

This command checks to see if there are new versions of swiftly itself and upgrades to them if possible.

`swiftly self-update`

## Uninstalling swiftly

swiftly can be safely removed with the following command:

`swiftly self-uninstall`

<details>
<summary>If you want to do so manually, please follow the instructions below:</summary>

NOTE: This will not uninstall any toolchains you have installed unless you do so manually with `swiftly uninstall all`.

1. (Optional) Remove all installed toolchains with `swiftly uninstall all`.

2. Remove the swiftly home and bin directories. The default location might be `~/.swiftpm` or `.local/share/swiftly`. You can refer to the environment variables `SWIFTLY_HOME_DIR` and `SWIFTLY_BIN_DIR` in your associated profile file (`.zprofile`, `.bash_profile`, `.murex_profile`, `.profile`, `fish/conf.d` or `nushell/autoload`).

3. Remove any sections swiftly added to your aforementioned profile file. These sections might look like this:

   ```sh
   # Added by swiftly
   . "/Users/<USERNAME>/.swiftly/env.sh"
   ```

4. Restart your shell and check you have correctly removed the swiftly environment.

</details>

## Contributing

Welcome to the Swift community!

Contributions to Swiftly are welcomed and encouraged! Please see the [Contributing to Swift guide](https://www.swift.org/contributing) and check out the [structure of the community](https://www.swift.org/community/#community-structure).

To be a truly great community, Swift needs to welcome developers from all walks of life, with different backgrounds, and with a wide range of experience. A diverse and friendly community will have more great ideas, more unique perspectives, and produce more great code. We will work diligently to make the Swift community welcoming to everyone.

To give clarity of what is expected of our members, Swift has adopted the code of conduct defined by the Contributor Covenant. This document is used across many open source communities, and we think it articulates our values well. For more, see the [Code of Conduct](https://www.swift.org/code-of-conduct/).

## Upgrade from previous

Swiftly prior to verion 1.0.0 had a different installation and delivery mechanism. Upgrading to the newest version of swiftly involves two steps:

1. Uninstall older swiftly
2. Install the newest swiftly using the instructions above

To uninstall the old swiftly, first locate the swiftly home directory, which is often in `~/.local/share/swiftly` and remove it. Then check your shell profile files (`~/.profile`, `~/.zprofile`, `~/.bash_profile`, or `~/.config/fish/conf.d`) and remove any entries that attempt to source the `env.sh` or `env.fish` file in the swiftly home directory. Finally, remove the symbolic links that swiftly placed in your `~/.local/bin` to toolchain binaries (e.g. `swift`, `clang`, `lldb`, etc.). These will likely be symbolic links to toolchain directories in the swiftly home directory. Remove them so that there aren't any orphaned path entries.

Restart your shell and/or terminal to get a fresh environment. You should be ready to install the new swiftly.

## FAQ

#### Why not install Swift through the package manager (e.g. `apt` or `yum`)?

Swift.org currently provides experimental [`.rpm` and `.deb`](https://forums.swift.org/t/rpm-and-debs-for-swift-call-for-the-community/49117) packages that allow you to install Swift via your package manager. While these are an effective way to install and update a single version of Swift, they aren't well suited to the task of installing multiple Swift toolchains that you can easily switch between. swiftly's target audience are Swift developers that switch between versions for the purposes of testing their libraries and applications. The `.deb` and `.rpm` also currently don't provide support for snapshot toolchains.

#### How is this different from [swiftenv](https://github.com/kylef/swiftenv)?

swiftenv is an existing Swift version manager which already has much of the functionality that swiftly will eventually have. It's an awesome tool, and if it's part of your workflow then we encourage you to keep using it! That said, swiftly is/will be different a few ways:

- swiftly is being built as a community driven effort, and through this collaboration, swiftly is an official installation tool for Swift toolchains. swiftly has helped to inform the creation of API endpoints maintained by the Swift project that it uses to retrieve information about what toolchains are available to install and to verify their expected signatures. swiftenv currently uses a third party API layer for this. Using an official API reduces the avenues for security vulnerabilities and also reduces the risk of downtime affecting Swift installations.

- swiftly will be written in Swift, which we think is important for maintainability and encouraging community contributions.

- swiftly has first-class support for installing and managing snapshot toolchains.

- swiftly has built in support for updating toolchains.

- swiftly is optimized for ease of installation. In addition, swiftly doesn't require any system dependencies to be installed on the user's system. While swiftenv is also relatively easy to install, it does involve cloning a git repository or using Homebrew, and it requires a few system dependencies (e.g. bash, curl, tar).
