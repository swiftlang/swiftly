# Use Swift Toolchains

swiftly use and swiftly run

Swiftly toolchains include a variety of compilers, linkers, debuggers, documentation generators, and other useful tools for working with Swift. Using a toolchain activates it so that when you run toolchain commands they are run with that version.

When you install a toolchain you can start using it right away. If you don't have any other toolchains installed then it becomes the default.

```
$ swiftly install latest
$ swift --version
Swift version 6.0.3 (swift-6.0.3-RELEASE)
Target: aarch64-unknown-linux-gnu
$ swift build    # Build with the current toolchain
```

When you have more than one toolchain installed then you can choose to use one of them with `swiftly use` for all subsequent commands like this:

```
$ swiftly install 5.10.1
$ swiftly install main-snapshot
$ swiftly use 5.10.1
$ swift build    # Builds with the 5.10.1 toolchain
$ swift test     # Tests with the 5.10.1 toolchain
$ swiftly use main-snapshot
$ swift build    # Builds with the latest snapshot toolchain on the main branch
$ lldb           # Run the debugger from the latest snapshot toolchain
```

The use command doesn't require a full version. It is sufficient to provide just a major version, or the major and minor versions. Swiftly will use the newest matching version that you have installed, if any.

```
$ swiftly use 5
swift --version  # Version matches the 5.10.1 toolchain that was installed above
```

If you're not certain which toolchain is in-use then use the bare `swiftly use` command to provide details:

```
$ swiftly use
Swift 5.10.1 (default)
```

You can print the exact toolchain location with the `--print-location` flag:

```
$ swiftly use --print-location
/Users/someuser/Library/Developer/Toolchains/swift-5.10.1-RELEASE.xctoolchain
```

## Sharing recommended toolchain versions

Swiftly can create and update a special `.swift-version` file at the top of your git repository so that you can share your toolchain preference with the rest of your team:

```
$ cd path/to/git/repository
$ swiftly use 6.0.1
A new file `path/to/git/repository/.swift-version` will be created to set the new in-use toolchain for this project.
Alternatively, you can set your default globally with the `--global-default` flag. Proceed with creating this file? (Y/n) Y
$ cat .swift-version
6.0.1
```

When a team member uses swiftly with this git repository the toolchain that is in use matches the version in the file.

```
$ cd path/to/git/repository
$ swift --version
Swift version 6.0.1 (swift-6.0.1-RELEASE)
Target: aarch64-unknown-linux-gnu
```

If that team member doesn't have the toolchain installed on their system there will be an error. They can install the selected toolchain automatically like this:

```
$ cd path/to/git/repository
$ swiftly install    # Installs the version of the toolchain in the .swift-version file
```

If you want to temporarily use a toolchain version for one command you can try `swiftly run`. This will build your package with the latest snapshot toolchain:

```
$ swiftly run swift build +main-snapshot
```

> Note: The toolchain must be installed on your system before you can run with it.

The `.swift version` file, if it is present in your working directory (or parent) will select the toolchain that is in use. If you are working in a directory that doesn't have this file, then you can set a global default toolchain to use in these places.

```
$ swiftly use --global-default 6.0.1
```

Here the `--global-default` flag ensures that the default is set globally to the "6.0.1" toolchain whenever there isn't a swift version file, and there isn't a version specified in the `swiftly run` command. Also, this flag doesn't attempt to create a swift version file, or update it if it already exists.

## In use toolchains and default toolchains

When you list installed toolchains or use the `swiftly use` command to print the current in use toolchain there will be tags for both "in use" and "default." Sometimes the same toolchain will have both tags!

```
$ swiftly list
Installed release toolchains
----------------------------
Swift 6.0.3
Swift 6.0.2 (in use) (default)

Installed snapshot toolchains
-----------------------------
```

Whenever a toolchain is tagged as "in use" indicates the toolchain that will be used when running toolchain commands from your current working directory. The one that is selected is based either on what is in a `.swift-version` file or the global default if there is no such file there.

The default tag is used to show the global default toolchain, which is independent of any swift version file. The global default is there for cases where the file doesn't exist. It sets the toolchain that is in use in those cases.
