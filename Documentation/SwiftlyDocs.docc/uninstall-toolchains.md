# Uninstall Swift toolchains

Remove unneeded Swift toolchains.

After installing several toolchains the list of the available toolchains may become unwieldy, and each toolchain can occupy substantial storage space.
This guide covers how to uninstall no longer needed toolchains that were installed with swiftly.

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

It can be time consuming to remove all of the snapshots that you have installed. You can remove all of the main or version snapshots with one command.

```
$ swiftly uninstall main-snapshot
$ swiftly uninstall 5.7-snapshot
```

You can see the installed toolchains that remain with the list subcommand:

```
$ swiftly list

Installed release toolchains
----------------------------
Swift 5.10.1 (in use)

Installed snapshot toolchains
-----------------------------
```

Here you have seen how you can uninstall toolchains in different ways using swiftly to help manage your development environment.
