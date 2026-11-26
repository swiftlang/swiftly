# Choosing a Swift Toolchain

Choose a Swift Toolchain for your workflow.

## Overview

Swift toolchains include a variety of tools for building, testing, debugging, formatting code, and IDE integration. There's also a set of foundational libraries in a toolchain that can have an impact to the way that your code builds and runs. All of these things have an impact on the development of your project.

Luckily, swiftly exists to make it easy to get a toolchain. Which one of the potentially large number do I pick? This question can be bewildering.

## What is the workflow?

Your workflow can be one way to decide what toolchain you should use.

### Getting started working on a project

When you're working on a particular project, such as developing a bug fix, or adding a feature, you'll want the toolchain that sets you up on a path to successfully getting your pull request merged at that point in time. Along the way, you are likely to need a toolchain that will successfully compie the code with the language features that it requires, and is also unlikely to have show-stopping problems in doing that.

Iterating on this code might involve using a supported IDE, such as VS Code, that makes use of a matching language server (sourcekit-lsp) that works with this code. Perhaps the code base uses certain features from Swift Testing, only available starting in a particular release. The version of swift-format can also have an impact on the formatting (and the formatting checks) on the code, so it will save time and increase confidence when formatting your new code to use the correct version. A developer would like the version that's most likely to succeed in all of these areas.

A project can publish the recommended default version of the specific toolchain in their developer's guide. This is a good start, and helps someone to get started with a good chance of success. Documention is often a worthwhile investment, but sometimes we can do better with tooling.

### Verifying a project

When verifying a project in something like a CI system, it's important to pick a toolchain that meets the objective of verifying that the current state of the code with a level of reliability. Using the [test pyramid](https://martinfowler.com/articles/practical-test-pyramid.html) model, you want to get the *majority* of tests running _quickly_, but also *reliably*.

Reliability in toolchain selection is knowing which toolchain has produced good results in the pastat a developer's desk, better would be to use one that's been verified in CI. And so, maybe the CI system uses the toolchain that's documented in the developer's guide? It can be a manual process, such as when the developer's guide is updated. Better would be to have some tooling support that handles both develpers getting started and toolchain selection in CI. In any case swiftly can help install the chosen default toolchain.

It is important to note it is often important to engage in certain kinds of testing that can be slower, and less reliable. The test pyramid model accommodates ths for doing integration, end-to-end testing. These should be fewer in number, and possibly less frequently. Since these tests can be less reliable and slower, sometimes they don't run with every pull request. They are commonly run on a schedule with processes in place to react to failures.

In terms of toolchain selection, it can be important (depending on the project), to have integration testing with different toolchains. Sometimes this involves exploratory testing new Swift toolchain snapshots to signal readiness before the next release arrives. In other cases, a sampling of toolchain versions (often older ones) are used to build the software so that downstream projects using older toolchains can be supported. Testing is harder to achieve since the test cases themselves are not directly consumed by downstream projects, and a project might want to adopt newer test features available in newer toolchains. swiftly can also help to install these toolchains for integration testing with them.

```
swiftly run +6.2-snapshot make
swiftly run +5.10.1 swift test
```

### Switching between projects and branches

Sometimes a developer is switching between many different projects, and in different branches. It can become a challenge to remember which toolchain should be used for each. This is much like the getting started working on a project objective, but with many different starting points. The objective is to use a toolchain that fosters a reliable experience, and also has a good chance of passing the majoprity of verification checks in CI when you open a pull request. Having some sort of inline documentation, such as a developer's guide can help with this since it can be customized for the project and revision. A standard location that works across projects is also possible, but not yet standardized. Once a developer finds this version, that's the one that they can ask swiftly to install.

## Tooling can be better than documentation

The general recommendation so far is to document the recommended toolchain version in a developer's guide, update it for each branch, and keep CI in sync with that. One of the big problems in documentation is keeping it up-to-date. Here we have to keep it up-to-date not just in each branch, but also in CI too. There can be a much better approach, and that involves tools.

swiftly is in the position of being able to install toolchains and switch between them automatically. If there is a standard way to write down the default version in the project's repository then it has the information that it needs to both install and switch to the recommended toolchain on behalf of the developer, and the CI system.

This is the purpose of the `.swift-version` file. It installs the recommended toolchain that should get you a reliable development environment, and CI environment given the current state of the project code. The format is very simple, just a single line with the full toolchain version:

```
6.1.1
```

That's all there is to it. It can be easily read/written by tools, including swiftly, because it's very simple. In the worst case, it is just another form of documentation, but standardized in terms of location and format. The reliability increases as more workflows begin using it. Developers use this toolchain to advance the code and establish a recommended version. CI systems can verify and block any changes that break with this version. Finally, developers can switch between projects that make use of it much more fluidly and easily.

swiftly is contributing to this effort by reading this file automatically. When switching toolchains it seeds them when you `swiftly install` or `swiftly use` a different toolchain.

### Other versions: Swift Tools

There are other sorts of versions in Swift. For a typical SwiftPM package, there's the "Swift Tools Version" at the top of the `Package.swift` file:

```
//swift-tools-version: 5.10

Package(
   name: "foo"
)
```

From the [SwiftPM documentation](https://docs.swift.org/package-manager/PackageDescription/PackageDescription.html#about-the-swift-tools-version) the first purpose of this version is to declare the version of the Package.swift file's contents so that it can be processed using the correct version of the package description structure. Another purpose is to set the minimum version of the "Swift tools" that are needed to use the package.

From this first purpose, this has not so much to do with the toolchain version, as it does with the need to understand the package description that's inside the file. Newer toolchains will fall back to this version of the description to get the package description. It's also in the best interest of a package to use an older version for this so that downstream packages can continue to use older toolchains.

In terms of the second purpose this acts as a lower-bound of the swift tools for reasons stated above. There are serious tensions between using this as the exact recommended version because there are additional concerns with developing, and testing this package that are not shared by consumers of it, such as features used in testing, formatting, and IDE integration.

Not every project that uses a Swift toolchain uses SwiftPM. There are cases where CMake is being used as the build system. In other cases the toolchain is used to access a particular release of clang. Both swiftly and the `.swift-version` file can be used in these cases too.

## Other versions: Swift Language Version

There is also a version that you can set for the Swift language. For example, SwiftPM allows you to set them for a [package](https://docs.swift.org/package-manager/PackageDescription/PackageDescription.html#swiftversion) in your `Package.swift` file.

```
Package(
    name: "foo",
    swiftLanguageVersions: [v5, v6]
)
```

This version is used to set the supported language modes in the Swift compiler because it can support handling source code from much older, and newer versions of the language. This has little to do with the recommended toolchain version to use for a project, and is much more about supporting legacy Swift code. There are similar settings for the C, and C++ language standards used by clang.

Newer toolchains can support much older language versions. For Swift versions, they tend to be only the major version, not the minor, and patch versions that uniquely identify an exact recommended toolchain.

## Summary

Depending on your workflow, there is often some kind of recommended toolchain version that can help you to succeed in the primary flow. What's needed is a standard way to record this information. The swift version file is a simple format to document the version. Tooling support, including swiftly, can help you to choose this recommended toolchain across different projects. While there are other sources of version information in Swift projects, they are designed for other things.

Having a single recommended version doesn't prevent you from using other toolchain versions for various purposes. There is room within the test pyramid model for integration testing with alternate versions. Swiftly has some mechanisms, such as the `swiftly run` version selector syntax, to automate testing with older and newer versions to support this style of integration testing, as well ad-hoc explorations too.
