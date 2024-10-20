# Use Swift Toolchains

swiftly use and swiftly run

Swiftly toolchains include a variety of compilers, linkers, debuggers, documentation generators, and other useful tools for working with Swift. Using a toolchain activates it so that when you run toolchain commands they are run with that version.

When you install a toolchain you can start using it right away. If you don't have any other toolchains installed then it becomes the default.

```
$ swiftly install latest
$ swift --version
Swift version 6.0.1 (swift-6.0.1-RELEASE)
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

If you're not certain which toolchain is in-use then use the bare `swiftly use` command to provide details:

```
$ swiftly use
Swift 6.0.1 (default)
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

When a team member uses swiftly with this git repository it can use the correct toolchain version automatically:

```
$ cd path/to/git/repository
$ swift --version
Swift version 6.0.1 (swift-6.0.1-RELEASE)
Target: aarch64-unknown-linux-gnu
```

If that team member doesn't have the toolchain installed on their system there will be a warning. They can install the selected toolchain automatically like this:

```
$ cd path/to/git/repository
$ swiftly install    # Installs the version of the toolchain in the .swift-version file
```

If you want to temporarily use a toolchain version for one command you can try `swiftly run`. This will build your package with the latest snapshot toolchain:

```
$ swiftly run swift build +main-snapshot
```

> Note: The toolchain must be installed on your system before you can run with it.
