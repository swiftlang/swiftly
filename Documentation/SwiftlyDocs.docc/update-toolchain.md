# Update Swift Toolchain

Update swift toolchains.

Update replaces a given toolchain with a later version of that toolchain. For a stable release, this means updating to a later patch, minor, or major version. For snapshots, this means updating to the most recently available snapshot. Swiftly can help you to keep up-to-date. We assume that you have installed swiftly and use it to manage your toolchains.

If no version is provided, update will update the currently selected toolchain to its latest patch release if a release toolchain or the latest available snapshot if a snapshot. The newly installed version will be selected.

```
swiftly update
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

Similarly, to update the latest snapshot associated with a specific version, the “a.b-snapshot” version can be supplied:

```
swiftly update 5.3-snapshot
```

You can also update the latest installed main snapshot to the latest available one by just providing `main-snapshot`:

```
swiftly update main-snapshot
```

Here you have seen how to use swiftly to update your toolchains to the latest, latest of a particular major/minor release, and even snapshots.
