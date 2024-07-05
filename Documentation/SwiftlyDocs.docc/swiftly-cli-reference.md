# swiftly

<!-- THIS FILE HAS BEEN GENERATED using the following command: swift package plugin generate-docs-reference -->

A utility for installing and managing Swift toolchains.

```
swiftly [--version] [--help]
```

**--version:**

*Show the version.*


**--help:**

*Show help information.*


## install

Install a new toolchain.

```
swiftly install <version> [--use] [--token=<token>] [--verify] [--version] [--help]
```

**version:**

*The version of the toolchain to install.*


The string "latest" can be provided to install the most recent stable version release:

    $ swiftly install latest

A specific toolchain can be installed by providing a full toolchain name, for example a stable release version with patch (e.g. a.b.c):

    $ swiftly install 5.4.2

Or a snapshot with date:

    $ swiftly install 5.7-snapshot-2022-06-20
    $ swiftly install main-snapshot-2022-06-20

The latest patch release of a specific minor version can be installed by omitting the patch version:

    $ swiftly install 5.6

Likewise, the latest snapshot associated with a given development branch can be installed by omitting the date:

    $ swiftly install 5.7-snapshot
    $ swiftly install main-snapshot


**--use:**

*Mark the newly installed toolchain as in-use.*


**--token=\<token\>:**

*A GitHub authentiation token to use for any GitHub API requests.*


This is useful to avoid GitHub's low rate limits. If an installation
fails with an "unauthorized" status code, it likely means the rate limit has been hit.


**--verify:**

*Verify the toolchain's PGP signature before proceeding with installation.*


**--version:**

*Show the version.*


**--help:**

*Show help information.*




## use

Set the active toolchain. If no toolchain is provided, print the currently in-use toolchain, if any.

```
swiftly use [<toolchain>] [--version] [--help]
```

**toolchain:**

*The toolchain to use.*


If no toolchain is provided, the currently in-use toolchain will be printed, if any:

    $ swiftly use

The string "latest" can be provided to use the most recent stable version release:

    $ swiftly use latest

A specific toolchain can be selected by providing a full toolchain name, for example a stable release version with patch (e.g. a.b.c):

    $ swiftly use 5.4.2

Or a snapshot with date:

    $ swiftly use 5.7-snapshot-2022-06-20
    $ swiftly use main-snapshot-2022-06-20

The latest patch release of a specific minor version can be used by omitting the patch version:

    $ swiftly use 5.6

Likewise, the latest snapshot associated with a given development branch can be used by omitting the date:

    $ swiftly use 5.7-snapshot
    $ swiftly use main-snapshot


**--version:**

*Show the version.*


**--help:**

*Show help information.*




## uninstall

Remove an installed toolchain.

```
swiftly uninstall <toolchain> [--assume-yes] [--version] [--help]
```

**toolchain:**

*The toolchain(s) to uninstall.*


The toolchain selector provided determines which toolchains to uninstall. Specific toolchains can be uninstalled by using their full names as the selector, for example a full stable release version with patch (a.b.c): 

    $ swiftly uninstall 5.2.1

Or a full snapshot name with date (a.b-snapshot-YYYY-mm-dd):

    $ swiftly uninstall 5.7-snapshot-2022-06-20

Less specific selectors can be used to uninstall multiple toolchains at once. For instance, the patch version can be omitted to uninstall all toolchains associated with a given minor version release:

    $ swiftly uninstall 5.6

Similarly, all snapshot toolchains associated with a given branch can be uninstalled by omitting the date:

    $ swiftly uninstall main-snapshot
    $ swiftly uninstall 5.7-snapshot

The latest installed stable release can be uninstalled by specifying  'latest':

    $ swiftly uninstall latest

Finally, all installed toolchains can be uninstalled by specifying 'all':

    $ swiftly uninstall all


**--assume-yes:**

*Uninstall all selected toolchains without prompting for confirmation.*


**--version:**

*Show the version.*


**--help:**

*Show help information.*




## list

List installed toolchains.

```
swiftly list [<toolchain-selector>] [--version] [--help]
```

**toolchain-selector:**

*A filter to use when listing toolchains.*


The toolchain selector determines which toolchains to list. If no selector is provided, all installed toolchains will be listed:

    $ swiftly list

The installed toolchains associated with a given major version can be listed by specifying the major version as the selector: 

    $ swiftly list 5

Likewise, the installed toolchains associated with a given minor version can be listed by specifying the minor version as the selector:

    $ swiftly list 5.2

The installed snapshots for a given devlopment branch can be listed by specifying the branch as the selector:

    $ swiftly list main-snapshot
    $ swiftly list 5.7-snapshot


**--version:**

*Show the version.*


**--help:**

*Show help information.*




## update

Update an installed toolchain to a newer version.

```
swiftly update [<toolchain>] [--assume-yes] [--verify] [--version] [--help]
```

**toolchain:**

*The installed toolchain to update.*


Updating a toolchain involves uninstalling it and installing a new toolchain that is newer than it.

If no argument is provided to the update command, the currently in-use toolchain will be updated. If that toolchain is a stable release, it will be updated to the latest patch version for that major.minor version. If the currently in-use toolchain is a snapshot, then it will be updated to the latest snapshot for that development branch.

    $ swiftly update

The string "latest" can be provided to update the installed stable release toolchain with the newest version to the latest available stable release. This may update the toolchain to later major, minor, or patch versions.

    $ swiftly update latest

A specific stable release can be updated to the latest patch version for that release by specifying the entire version:

    $ swiftly update 5.6.0

Omitting the patch in the specified version will update the latest installed toolchain for the provided minor version to the latest available release for that minor version. For example, the following will update the latest installed Swift 5.4 release toolchain to the latest available Swift 5.4 release:

    $ swiftly update 5.4

Similarly, omitting the minor in the specified version will update the latest installed toolchain for the provided major version to the latest available release for that major version. Note that this may update the toolchain to a later minor version.

    $ swiftly update 5

The latest snapshot toolchain for a given development branch can be updated to the latest available snapshot for that branch by specifying just the branch:

    $ swiftly update 5.7-snapshot
    $ swiftly update main-snapshot

A specific snapshot toolchain can be updated by including the date:

    $ swiftly update 5.9-snapshot-2023-09-20
    $ swiftly update main-snapshot-2023-09-20


**--assume-yes:**

*Update the selected toolchains without prompting for confirmation.*


**--verify:**

*Verify the toolchain's PGP signature before proceeding with installation.*


**--version:**

*Show the version.*


**--help:**

*Show help information.*




## self-update

Update the version of swiftly itself.

```
swiftly self-update [--version] [--help]
```

**--version:**

*Show the version.*


**--help:**

*Show help information.*




