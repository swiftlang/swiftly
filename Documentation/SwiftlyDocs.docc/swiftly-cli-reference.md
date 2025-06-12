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
swiftly install [<version>] [--use] [--verify|no-verify] [--post-install-file=<post-install-file>] [--assume-yes] [--verbose] [--version] [--help]
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

Install whatever toolchain is currently selected, such as the the one in the .swift-version file:

    $ swiftly install

NOTE: Swiftly downloads toolchains to a temporary file that it later cleans during its installation process. If these files are too big for your system temporary directory, set another location by setting the `TMPDIR` environment variable.

    $ TMPDIR=/large/file/tmp/storage swiftly install latest


**--use:**

*Mark the newly installed toolchain as in-use.*


**--verify|no-verify:**

*Verify the toolchain's PGP signature before proceeding with installation.*


**--post-install-file=\<post-install-file\>:**

*A file path to a location for a post installation script*

If the toolchain that is installed has extra post installation steps, they will be
written to this file as commands that can be run after the installation.


**--assume-yes:**

*Disable confirmation prompts by assuming 'yes'*


**--verbose:**

*Enable verbose reporting from swiftly*


**--version:**

*Show the version.*


**--help:**

*Show help information.*




## list-available

List toolchains available for install.

```
swiftly list-available [<toolchain-selector>] [--version] [--help]
```

**toolchain-selector:**

*A filter to use when listing toolchains.*


The toolchain selector determines which toolchains to list. If no selector is provided, all available release toolchains will be listed:

    $ swiftly list-available

The available toolchains associated with a given major version can be listed by specifying the major version as the selector: 

    $ swiftly list-available 5

Likewise, the available toolchains associated with a given minor version can be listed by specifying the minor version as the selector:

    $ swiftly list-available 5.2

The installed snapshots for a given development branch can be listed by specifying the branch as the selector:

    $ swiftly list-available main-snapshot
    $ swiftly list-available x.y-snapshot

Note that listing available snapshots before the latest release (major and minor number) is unsupported.


**--version:**

*Show the version.*


**--help:**

*Show help information.*




## use

Set the in-use or default toolchain. If no toolchain is provided, print the currently in-use toolchain, if any.

```
swiftly use [--print-location] [--global-default] [--format=<format>] [--assume-yes] [--verbose] [<toolchain>] [--version] [--help]
```

**--print-location:**

*Print the location of the in-use toolchain. This is valid only when there is no toolchain argument.*


**--global-default:**

*Set the global default toolchain that is used when there are no .swift-version files.*


**--format=\<format\>:**

*Output format (text, json)*


**--assume-yes:**

*Disable confirmation prompts by assuming 'yes'*


**--verbose:**

*Enable verbose reporting from swiftly*


**toolchain:**

*The toolchain to use.*


If no toolchain is provided, the currently in-use toolchain will be printed, if any. This is based on the current working directory and `.swift-version` files if one is present. If the in-use toolchain is also the global default then it will be shown as the default.

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
swiftly uninstall <toolchain> [--assume-yes] [--verbose] [--version] [--help]
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

*Disable confirmation prompts by assuming 'yes'*


**--verbose:**

*Enable verbose reporting from swiftly*


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

The installed snapshots for a given development branch can be listed by specifying the branch as the selector:

    $ swiftly list main-snapshot
    $ swiftly list 5.7-snapshot


**--version:**

*Show the version.*


**--help:**

*Show help information.*




## update

Update an installed toolchain to a newer version.

```
swiftly update [<toolchain>] [--assume-yes] [--verbose] [--verify|no-verify] [--post-install-file=<post-install-file>] [--version] [--help]
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

*Disable confirmation prompts by assuming 'yes'*


**--verbose:**

*Enable verbose reporting from swiftly*


**--verify|no-verify:**

*Verify the toolchain's PGP signature before proceeding with installation.*


**--post-install-file=\<post-install-file\>:**

*A file path to a location for a post installation script*

If the toolchain that is installed has extra post installation steps they they will be
written to this file as commands that can be run after the installation.


**--version:**

*Show the version.*


**--help:**

*Show help information.*




## init

Perform swiftly initialization into your user account.

```
swiftly init [--no-modify-profile] [--overwrite] [--platform=<platform>] [--skip-install] [--quiet-shell-followup] [--assume-yes] [--verbose] [--version] [--help]
```

**--no-modify-profile:**

*Do not attempt to modify the profile file to set environment variables (e.g. PATH) on login.*


**--overwrite:**

*Overwrite the existing swiftly installation found at the configured SWIFTLY_HOME, if any. If this option is unspecified and an existing installation is found, the swiftly executable will be updated, but the rest of the installation will not be modified.*


**--platform=\<platform\>:**

*Specify the current Linux platform for swiftly*


**--skip-install:**

*Skip installing the latest toolchain*


**--quiet-shell-followup:**

*Quiet shell follow up commands*


**--assume-yes:**

*Disable confirmation prompts by assuming 'yes'*


**--verbose:**

*Enable verbose reporting from swiftly*


**--version:**

*Show the version.*


**--help:**

*Show help information.*




## self-update

Update the version of swiftly itself.

```
swiftly self-update [--assume-yes] [--verbose] [--version] [--help]
```

**--assume-yes:**

*Disable confirmation prompts by assuming 'yes'*


**--verbose:**

*Enable verbose reporting from swiftly*


**--version:**

*Show the version.*


**--help:**

*Show help information.*




## run

Run a command while proxying to the selected toolchain commands.

```
swiftly run <command>... [--version] [--help]
```

**command:**

*Run a command while proxying to the selected toolchain commands.*


Run a command with a selected toolchain. The toolchain commands become the default in the system path.

You can run one of the usual toolchain commands directly:

    $ swiftly run swift build

Or you can run another program (or script) that runs one or more toolchain commands:

    $ CC=clang swiftly run make  # Builds targets using clang
    $ swiftly run ./build-things.sh  # Script invokes 'swift build' to create certain product binaries

Toolchain selection is determined by swift version files `.swift-version`, with a default global as the fallback. See the `swiftly use` command for more details.

You can also override the selection mechanisms temporarily for the duration of the command using a special syntax. An argument prefixed with a '+' will be treated as the selector.

    $ swiftly run swift build +latest
    $ swiftly run swift build +5.10.1

The first command builds the swift package with the latest toolchain and the second selects the 5.10.1 toolchain. Note that if these aren't installed then run will fail with an error message. You can pre-install the toolchain using `swiftly install <toolchain>` to ensure success.

If the command that you are running needs the arguments with the '+' prefixes then you can escape it by doubling the '++'.

    $ swiftly run ./myscript.sh ++abcde

The script will receive the argument as '+abcde'. If there are multiple arguments with the '+' prefix that should be escaped you can disable the selection using a '++' argument, which turns off any selector argument processing for subsequent arguments. This is analogous to the '--' that turns off flag and option processing for subsequent arguments in many argument parsers.

    $ swiftly run ./myscript.sh ++ +abcde +xyz

The script will receive the argument '+abcde' followed by '+xyz'.


**--version:**

*Show the version.*


**--help:**

*Show help information.*




## link

Link swiftly so it resumes management of the active toolchain.

```
swiftly link [<toolchain-selector>] [--assume-yes] [--verbose] [--version] [--help]
```

**toolchain-selector:**

*Links swiftly if it has been disabled.*


Links swiftly if it has been disabled.


**--assume-yes:**

*Disable confirmation prompts by assuming 'yes'*


**--verbose:**

*Enable verbose reporting from swiftly*


**--version:**

*Show the version.*


**--help:**

*Show help information.*




## unlink

Unlinks swiftly so it no longer manages the active toolchain.

```
swiftly unlink [<toolchain-selector>] [--assume-yes] [--verbose] [--version] [--help]
```

**toolchain-selector:**

*Unlinks swiftly, allowing the system default toolchain to be used.*


Unlinks swiftly until swiftly is linked again with:

    $ swiftly link


**--assume-yes:**

*Disable confirmation prompts by assuming 'yes'*


**--verbose:**

*Enable verbose reporting from swiftly*


**--version:**

*Show the version.*


**--help:**

*Show help information.*




