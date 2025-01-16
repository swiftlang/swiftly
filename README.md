# swiftly

swiftly is a CLI tool for installing, managing, and switching between [Swift](https://www.swift.org/) toolchains, written in Swift. swiftly itself is designed to be extremely easy to install and get running, and its command interface is intended to be flexible while also being simple to use. The overall experience is inspired by and meant to feel reminiscent of the Rust toolchain manager [rustup](https://rustup.rs/).

Ongoing maintenance and stewardship of this project is led by the [SSWG](https://www.swift.org/sswg/).

### Installation

Install swiftly using a script (hosted from this repository) using the command:

```
curl -L https://swiftlang.github.io/swiftly/swiftly-install.sh | bash
```

In the future, download the swiftly package from [swift.org](https://swift.org/download) and it can install itself with init:

```
swiftly init
```

### Basic usage

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

## Features

- Installing multiple toolchains, including both stable releases and snapshots
- Switching which installed toolchain is active (i.e. which one is discovered via `$PATH`)
- Updating installed toolchains to the latest available versions of those toolchains
- Uninstalling installed toolchains
- Listing the toolchains that are available to install (not yet implemented)

## Platform support

- Linux-based platforms listed on https://swift.org/download

Right now, swiftly is in early stages of development and is supported on Linux and macOS. For more detailed information about swiftly's intended features and implementation, check out the [design document](DESIGN.md).

## Command interface overview

### Installing a toolchain

#### Install the latest version of Swift

```
$ swiftly install latest
```

#### Installing a specific release version of Swift

A specific version of Swift can be provided to the `install` command. 

```
$ swiftly install 5.6.1
```

If a patch version isn't specified, swiftly will look up and install the latest patch version that matches the minor version provided:

```
$ swiftly install 5.6
```

#### Installing main development snapshots (trunk)

```
$ swiftly install main-snapshot-2022-01-28
```

If the date isn't specified, swiftly will look up and install the latest available snapshot:

```
$ swiftly install main-snapshot
```

#### Installing Swift version development snapshots

```
$ swiftly install 5.7-snapshot-2022-08-30
```

If the date isn't specified, swiftly will look up and install the latest snapshot associated with the provided development branch:

```
$ swiftly install 5.7-snapshot
```

### Uninstalling a toolchain

#### Uninstall a release toolchain

```
$ swiftly uninstall 5.6.3
```

To uninstall all toolchains associated with a given minor release, leave off the patch version:

```
$ swiftly uninstall 5.6
```

#### Uninstall a snapshot toolchain

```
$ swiftly uninstall main-snapshot-2022-08-30
$ swiftly uninstall 5.7-snapshot-2022-08-30
```

To uninstall all snapshots associated with a given branch (either main or a release branch), omit the date:

```
$ swiftly uninstall main-snapshot
$ swiftly uninstall 5.7-snapshot
```

### Listing installed toolchains

The `list` command prints all the toolchains installed by swiftly:

```
$ swiftly list
```

### Selecting a toolchain for use

“Using” a toolchain sets it as the active toolchain, meaning it will be the one found via $PATH and invoked via `swift` commands executed in the shell. The toolchain must be installed before you can use it.

You can provide the same version selectors as you used with `swiftly install` to use a toolchain, including exact releacs versions "major.minor.patch", and snapshots.

```
$ swiftly use latest
$ swiftly use 5.3.1
$ swiftly use 5.3
$ swiftly use 5.3-snapshot
$ swiftly use 5.3-snapshot-2022-08-16
$ swiftly use main-snapshot
$ swiftly use main-snapshot-2024-06-18
```

After you use a toolchain your commands at the shell will run with that toolchain:

```
$ swiftly use x.y.z
$ swift build             # Build my package with toolchain version x.y.z
$ clang -c foo.c -o foo.o # Compile this C file using the clang compiler in toolchain version x.y.z
$ lldb                    # Open the debugger from toolchain version x.y.z
```

If you want to run just one command with a particular toolchain without having to switch back to the one you used previously you can use the `swiftly run` command with the version. This command builds your current package with the latest snapshot toolchain of the current release:

```
$ swiftly run swift build +main-snapshot
```

The parameter with the "+" indicates that this is the version selector of the toolchain to use and supports the full range of selectors shown above and with the `swiftly install` command. The toolchain must be installed to run a command with that toolchain.

### Updating a toolchain

Update replaces a given toolchain with a later version of that toolchain. For a stable release, this means updating to a later patch, minor, or major version. For snapshots, this means updating to the most recently available snapshot. 

If no version is provided, update will update the currently selected toolchain to its latest patch release if a release toolchain or the latest available snapshot if a snapshot. The newly installed version will be selected.

```
$ swiftly update
```

To update the latest installed release version to the latest available release version, the “latest” version can be provided. Note that this may update the toolchain to the next minor or even major version.

```
swiftly update latest
```

If only a major version is specified, the latest installed toolchain with that major version will be updated to the latest available release of that major version:

```
swiftly update 5
```

If the major and minor version are specified, the latest installed toolchain associated with that major/minor version will be updated to the latest available patch release for that major/minor version.

```
swiftly update 5.3
```

You can also specify a full version to update that toolchain to the latest patch available for that major/minor version:

```
swiftly update 5.3.1
```

Similarly, to update the latest snapshot associated with a specific version, the “a.b-snapshot” version can be supplied:

```
swiftly update 5.3-snapshot
```

You can also update the latest installed main snapshot to the latest available one by just providing `main-snapshot`:

```
swiftly update main-snapshot
```

A specific snapshot toolchain can be updated to the newest available snapshot for that branch by including the date:

```
swiftly update 5.9-snapshot-2023-09-20
```

### Listing toolchains available to install

The `list-available` command can be used to list the latest toolchains that Apple has made available to install.

Note that this command isn't implemented yet, but it will be included in a future release.

```
swiftly list-available
```

A selector can optionally be provided to narrow down the results:

```
$ swiftly list-available 5.6
$ swiftly list-available main-snapshot
$ swiftly list-available 5.7-snapshot
```

### Updating swiftly

This command checks to see if there are new versions of `swiftly` itself and upgrades to them if so.

Note that this command isn't implemented yet, but it will be included in a future release.

`swiftly self-update`

### Specifying a snapshot toolchain

The canonical name for a snapshot toolchain in swiftly's command interface is the following:

```
<branch>-snapshot-YYYY-MM-DD
```

However, swiftly also accepts the snapshot toolchain filenames from the downloads provided by swift.org. For example:

```
swift-DEVELOPMENT-SNAPSHOT-2022-09-10-a
swift-5.7-DEVELOPMENT-SNAPSHOT-2022-08-30-a
```

The canonical name format was chosen to reduce the keystrokes needed to refer to a snapshot toolchain, but the longer form is also useful when copy/pasting a toolchain name provided from somewhere else.

## Contributing 
Welcome to the Swift community!

Contributions to Swiftly are welcomed and encouraged! Please see the [Contributing to Swift guide](swift.org/contributing) and check out the [structure of the community](https://www.swift.org/community/#community-structure).

To be a truly great community, Swift needs to welcome developers from all walks of life, with different backgrounds, and with a wide range of experience. A diverse and friendly community will have more great ideas, more unique perspectives, and produce more great code. We will work diligently to make the Swift community welcoming to everyone.

To give clarity of what is expected of our members, Swift has adopted the code of conduct defined by the Contributor Covenant. This document is used across many open source communities, and we think it articulates our values well. For more, see the [Code of Conduct](https://www.swift.org/code-of-conduct/).
 
## FAQ

#### Why not install Swift through the package manager (e.g. `apt` or `yum`)?

Swift.org currently provides experimental [`.rpm` and `.deb`](https://forums.swift.org/t/rpm-and-debs-for-swift-call-for-the-community/49117) packages that allow you to install Swift via your package manager. While these are an effective way to install and update a single version of Swift, they aren't well suited to the task of installing multiple Swift toolchains that you can easily switch between. swiftly's target audience are Swift developers that switch between versions for the purposes of testing their libraries and applications. The `.deb` and `.rpm` also currently don't provide support for snapshot toolchains.

#### How is this different from [swiftenv](https://github.com/kylef/swiftenv)?

swiftenv is an existing Swift version manager which already has much of the functionality that swiftly will eventually have. It's an awesome tool, and if it's part of your workflow then we encourage you to keep using it! That said, swiftly is/will be different a few ways:

- swiftly is being built as a community driven effort led by the Swift server workgroup, and through this collaboration, swiftly will eventually become an official installation tool for Swift toolchains. As first step towards that, swiftly will help inform the creation of API endpoints maintained by the Swift project that it will use to retrieve information about what toolchains are available to install and to verify their expected signatures. swiftenv currently uses a third party API layer for this. Using an official API reduces the avenues for security vulnerabilities and also reduces the risk of downtime affecting Swift installations.

- swiftly will be written in Swift, which we think is important for maintainability and encouraging community contributions. 

- swiftly has first-class support for installing and managing snapshot toolchains.

- swiftly has built in support for updating toolchains.

- swiftly is optimized for ease of installation--it can be done with a bash one-liner similar to Homebrew and rustup. In addition, swiftly won't require any system dependencies to be installed on the user's system. While swiftenv is also relatively easy to install, it does involve cloning a git repository or using Homebrew, and it requires a few system dependencies (e.g. bash, curl, tar).

