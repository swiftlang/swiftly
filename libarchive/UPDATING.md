# Updating libarchive

Libarchive is vendored here so that it can be statically linked consistently into the swiftly binary on Linux independently of whether it is available as a shared libary or archive on the build system. Also, vendoring has the benefit of setting the precise configuration that we want for swiftly. From time-to-time the library will need to be updated from upstream. This can be done using the `git subtree` feature to pull in the changes on a new release tag (e.g. v3.7.5)

```
git subtree pull --prefix libarchive https://github.com/libarchive/libarchive.git v3.7.5 --squash
```

The squash option will squash the changes so that they don't crowd the swiftly history with the remote's history, just two commits with the summary.
