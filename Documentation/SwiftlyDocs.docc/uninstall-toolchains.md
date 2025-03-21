# Uninstall Swift Toolchains

swiftly uninstall

After installing several toolchains the list of the available toolchains to use becomes too large. Each toolchain also occupies substantial storage space. It's good to be able to cleanup toolchains when they aren't needed anymore. This guide will cover how to uninstall your toolchains assuming that you have installed swiftly and used it to install them.

If you have a released version that you want to uninstall then give the exact three digit version (major, minor and patch):

```
$ swiftly uninstall 5.6.1
```

When you're done working with every patch of a minor swift release you can remove them all by omitting the patch version.

```
$ swiftly uninstall 5.6
```

Snapshots can be removed individually using the version (or main) and the date.

```
$ swiftly uninstall main-snapshot-2022-08-30
$ swiftly uninstall 5.7-snapshot-2022-08-30
```

It can be time consuming to remove all of the snapshots that you have installed. You can remove all of the snapshots on a version, or main with one command.

```
$ swiftly uninstall main-snapshot
$ swiftly uninstall 5.7-snapshot
```

You can see what toolchahins remain with the list subcommand like this:

```
$ swiftly list

Installed release toolchains
----------------------------
Swift 5.10.1 (in use)

Installed snapshot toolchains
-----------------------------
```

Here you have seen how you can uninstall toolchains in different ways using swiftly to help manage your development environment.
