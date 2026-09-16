# Access Tools from Different Sources

Access tools that can be from different sources.

swiftly installs and manages toolchains for you that are available from swift.org. It sets up your shell environment to work well with these. There are other sources of Swift toolchains, and the common tools found in them, too. How do I access these from within my swiftly environment?

Also, sometimes it's difficult to determine whether there is a bug in swiftly itself, or the bug lies in the particular toolchain at swift.org. How can I figure this out?

If the tool is in a toolchain managed by swiftly it will call it directly when you run "swift", "clang", or "lldb". If you want to access the particular tool directly you can use `swiftly run` to run it like this wit the particular version of toolchain that you want:

```
swiftly run clang --version
```

If you want to bypass swiftly's run mechanism you can find the location of the tool and run it from it's fully qualified path:

```
$(swiftly use --print-location)/usr/bin/clang --version
```

Normally, when you install swiftly it places a set of proxy tools for the usual Swift toolchain commands. These are run in place of the actual toolchain so that swiftly can route them to the in use toolchain based on your configuration. If you want to bypass swiftly entirely, or use tools that were installed separately from swiftly there is also the ability to "unlink" swiftly's proxy binaries from your PATH.

```
swiftly unlink
```

Now, when you run "swift" and other tools they will be found elsewhere on your system (or not found at all). The "swiftly" command should still be available, so you can still find the location of the in use toolchain and other swiftly commands.

```
swiftly use --print-location
```

For instance, you can use this path to call a tool directly, or manually construct your path with it. You can also use swiftly to link the proxies again to get back to where you were before:

```
swiftly link
```

In this guide you have seen a few different ways to access tools installed by swiftly, and ones that are installed separately.
