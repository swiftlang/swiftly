# swiftly

swiftly is a CLI tool for installing, managing, and switching between Swift toolchains, written in Swift. swiftly itself is designed to be extremely easy to install and get running, and its command interface is intended to be flexible while also being simple to use. The overall experience is inspired by and meant to feel reminiscient of the Rust toolchain manager [rustup]().

Ongoing maintenance and stewardship of this project is led by the [SSWG](https://www.swift.org/sswg/).

## Current development status

Right now, swiftly is in the very early stages of development and is working towards an MVP for the Linux platforms mentioned on https://swift.org/download. Once that is complete, work will begin on an MVP for macOS. For more detailed information about swiftly's intended features and implementation, check out the [design document](DESIGN.md).

## Features

- Install multiple toolchains, including both stable releases and snapshots
- Switch which installed toolchain is active (i.e. switch which one is discovered via `$PATH`)
- Update installed toolchains to the latest available versions of those toolchains
- Uninstall intalled toolchains
- List the toolchains that are available to install

### Basic Usage

```
$ swiftly install latest

Fetching the latest stable Swift release...
Installing Swift 5.6.3
Downloaded 488.5 MiB of 488.5 MiB
Extracting toolchain...
Swift 5.6.3 installed successfully!

$ swift --version

Swift version 5.6.3 (swift-5.6.3-RELEASE)
Target: x86_64-unknown-linux-gnu
```

## Command overview

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

### Uninstalling toolchains

#### Uninstall a release toolchain

```
$ swiftly uninstall 5.6.3
```

To uninstall all toolchains associated with a given minor release, leave off the patch version:

```
$ swiftly unintall 5.6
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

### List installed toolchains

The `list` command prints all the toolchains installed by swiftly:

```
$ swiftly list
```

### Selecting a toolchain for use

“Using” a toolchain sets it as the active toolchain, meaning it will be the one found via $PATH and invoked via `swift` commands executed in the shell.

To use the toolchain associated with the most up-to-date Swift version, the “latest” version can be specified:

```
$ swiftly use latest
```

To use a specific stable version of Swift already installed, specify the major/minor/patch version:

```
$ swiftly use 5.3.1
```

To use the latest installed patch version associated with a given major/minor version pair, the patch can be omitted:

```
$ swiftly use 5.3
```

To use a specific snapshot version, specify the full snapshot version name:

```
$ swiftly use 5.3-snapshot-YYYY-MM-DD
```

To use the latest installed snapshot associated with a given version, the date can be omitted:

```
$ swiftly use 5.3-snapshot
```

To use a specific main snapshot, specify the full snapshot version name:

```
$ swiftly use main-snapshot-YYYY-MM-DD
```

To use the latest installed main snapshot, leave off the date:

```
$ swiftly use main-snapshot
```

### Update toolchains

Update replaces a given toolchain with a later version of that toolchain. For a stable release, this means updating to a later patch version. For snapshots, this means updating to the most recently available snapshot. 

If no version is provided, update will update the currently selected toolchain to its latest version while removing the old version. The newly installed version will be used.

```
$ swiftly update
```

To update the latest installed stable version, the “latest” version can be provided:

```
swiftly update latest
```

To update to the latest patch release of a given major/minor version, only the major/minor pair need to be provided. This will update the latest installed toolchain associated with that major/minor version to the latest patch release for that major/minor version.

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

### Listing available toolchains

The `list-available` command can be used to list the latest toolchains that Apple has made available to install.

```
swiftly list-available
```

A selector can optionally be provided to narrow down the results:

```
$ swiftly list-available 5.6
$ swiftly list-available main-snapshot
$ swiftly list-available 5.7-snapshot
```

### self-update

This command checks to see if there are new versions of `swiftly` itself and upgrades to them if so.

`swiftly self-update`

### Specifying a GitHub access token

swiftly currently uses the GitHub API to look up the available Swift toolchains. To avoid running up against rate limits, you can provide a [GitHub access token](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token) via the `--token` option (the token doesn't need any permissions):

```
$ swiftly install latest --token <GitHub authentication token>
```

## FAQ

#### How is this different from [swiftenv](https://github.com/kylef/swiftenv)?

swiftenv is an existing Swift version manager which already has much of the functionality that swiftly will eventually have. It's an awesome piece of software, and if it's part of your workflow then we encourage you to keep using it! That said, swiftly is/will be different a few important ways that may be worth considering:

- swiftly is optimized for ease of installation. Ideally, this could be done with a bash one-liner similar to rustup. In addition, it doesn't require any system dependencies to be installed on the user's system. swiftenv is also relatively easy to install, but it does involve cloning a git repository or using Homebrew, and it requires a few system dependencies (e.g. bash, curl, tar).

- swiftly is being built in cooperation with Apple via the SSWG. Through this, swiftly will help inform the creation of official Apple API endpoints that it will use to get information about what toolchains are available to install. swiftenv currently uses a third party API layer for this. Using an official API reduces the avenues for security vulnerabilities and also reduces the risk of downtime affecting Swift installations. Note that this is planned for the future--swiftly currently uses the GitHub API for this purpose.

- swiftly will be written in Swift, which we think is important for maintainability and encouraging community contributions. swiftenv is currently implemented in bash.

- swiftly has first-class support for installing and managing snapshot toolchains.

- swiftly has built in support for updating toolchains.
