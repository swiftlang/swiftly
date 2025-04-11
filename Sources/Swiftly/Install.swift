import _StringProcessing
import ArgumentParser
import Foundation
import SwiftlyCore
@preconcurrency import TSCBasic
import TSCUtility

struct Install: SwiftlyCommand {
    public static let configuration = CommandConfiguration(
        abstract: "Install a new toolchain."
    )

    @Argument(
        help: ArgumentHelp(
            "The version of the toolchain to install.",
            discussion: """

            The string "latest" can be provided to install the most recent stable version release:

                $ swiftly install latest

            A specific toolchain can be installed by providing a full toolchain name, for example \
            a stable release version with patch (e.g. a.b.c):

                $ swiftly install 5.4.2

            Or a snapshot with date:

                $ swiftly install 5.7-snapshot-2022-06-20
                $ swiftly install main-snapshot-2022-06-20

            The latest patch release of a specific minor version can be installed by omitting the \
            patch version:

                $ swiftly install 5.6

            Likewise, the latest snapshot associated with a given development branch can be \
            installed by omitting the date:

                $ swiftly install 5.7-snapshot
                $ swiftly install main-snapshot

            Install whatever toolchain is currently selected, such as the the one in the .swift-version file:

                $ swiftly install

            NOTE: Swiftly downloads toolchains to a temporary file that it later cleans during its installation process. If these files are too big for your system temporary directory, set another location by setting the `TMPDIR` environment variable.

                $ TMPDIR=/large/file/tmp/storage swiftly install latest
            """
        ))
    var version: String?

    @Flag(name: .shortAndLong, help: "Mark the newly installed toolchain as in-use.")
    var use: Bool = false

    @Flag(
        inversion: .prefixedNo,
        help: "Verify the toolchain's PGP signature before proceeding with installation."
    )
    var verify = true

    @Option(
        help: ArgumentHelp(
            "A file path to a location for a post installation script",
            discussion: """
            If the toolchain that is installed has extra post installation steps, they will be
            written to this file as commands that can be run after the installation.
            """
        ))
    var postInstallFile: String?

    @OptionGroup var root: GlobalOptions

    private enum CodingKeys: String, CodingKey {
        case version, use, verify, postInstallFile, root
    }

    mutating func run() async throws {
        try await self.run(Swiftly.createDefaultContext())
    }

    mutating func run(_ ctx: SwiftlyCoreContext) async throws {
        try validateSwiftly(ctx)

        var config = try Config.load(ctx)

        var selector: ToolchainSelector

        if let version = self.version {
            selector = try ToolchainSelector(parsing: version)
        } else {
            if case let (_, result) = try await selectToolchain(ctx, config: &config),
               case let .swiftVersionFile(_, sel, error) = result
            {
                if let sel = sel {
                    selector = sel
                } else if let error = error {
                    throw error
                } else {
                    throw SwiftlyError(message: "Internal error selecting toolchain to install.")
                }
            } else {
                throw SwiftlyError(
                    message:
                    "Swiftly couldn't determine the toolchain version to install. Please set a version like this and try again: `swiftly install latest`"
                )
            }
        }

        let toolchainVersion = try await Self.resolve(ctx, config: config, selector: selector)
        let (postInstallScript, pathChanged) = try await Self.execute(
            ctx,
            version: toolchainVersion,
            &config,
            useInstalledToolchain: self.use,
            verifySignature: self.verify,
            verbose: self.root.verbose,
            assumeYes: self.root.assumeYes
        )

        let shell =
            if let s = ProcessInfo.processInfo.environment["SHELL"]
        {
            s
        } else {
            try await Swiftly.currentPlatform.getShell()
        }

        // Fish doesn't cache its path, so this instruction is not necessary.
        if pathChanged && !shell.hasSuffix("fish") {
            await ctx.print(
                """
                NOTE: Swiftly has updated some elements in your path and your shell may not yet be
                aware of the changes. You can update your shell's environment by running

                hash -r

                or restarting your shell.

                """)
        }

        if let postInstallScript {
            guard let postInstallFile = self.postInstallFile else {
                throw SwiftlyError(
                    message: """

                    There are some dependencies that should be installed before using this toolchain.
                    You can run the following script as the system administrator (e.g. root) to prepare
                    your system:

                    \(postInstallScript)
                    """)
            }

            try Data(postInstallScript.utf8).write(
                to: URL(fileURLWithPath: postInstallFile), options: .atomic
            )
        }
    }

    public static func execute(
        _ ctx: SwiftlyCoreContext,
        version: ToolchainVersion,
        _ config: inout Config,
        useInstalledToolchain: Bool,
        verifySignature: Bool,
        verbose: Bool,
        assumeYes: Bool
    ) async throws -> (postInstall: String?, pathChanged: Bool) {
        guard !config.installedToolchains.contains(version) else {
            await ctx.print("\(version) is already installed.")
            return (nil, false)
        }

        // Ensure the system is set up correctly before downloading it. Problems that prevent installation
        //  will throw, while problems that prevent use of the toolchain will be written out as a post install
        //  script for the user to run afterwards.
        let postInstallScript = try await Swiftly.currentPlatform.verifySystemPrerequisitesForInstall(
            ctx, platformName: config.platform.name, version: version,
            requireSignatureValidation: verifySignature
        )

        await ctx.print("Installing \(version)")

        let tmpFile = Swiftly.currentPlatform.getTempFilePath()
        FileManager.default.createFile(atPath: tmpFile.path, contents: nil)
        defer {
            try? FileManager.default.removeItem(at: tmpFile)
        }

        var platformString = config.platform.name
        var platformFullString = config.platform.nameFull

#if !os(macOS) && arch(arm64)
        platformString += "-aarch64"
        platformFullString += "-aarch64"
#endif

        let category: String
        switch version {
        case let .stable(stableVersion):
            // Building URL path that looks like:
            // swift-5.6.2-release/ubuntu2004/swift-5.6.2-RELEASE/swift-5.6.2-RELEASE-ubuntu20.04.tar.gz
            var versionString = "\(stableVersion.major).\(stableVersion.minor)"
            if stableVersion.patch != 0 {
                versionString += ".\(stableVersion.patch)"
            }

            category = "swift-\(versionString)-release"
        case let .snapshot(release):
            switch release.branch {
            case let .release(major, minor):
                category = "swift-\(major).\(minor)-branch"
            case .main:
                category = "development"
            }
        case .xcode:
            fatalError("unreachable: xcode toolchain cannot be installed with swiftly")
        }

        let animation = PercentProgressAnimation(
            stream: stdoutStream,
            header: "Downloading \(version)"
        )

        var lastUpdate = Date()

        let toolchainFile = ToolchainFile(
            category: category, platform: platformString, version: version.identifier,
            file:
            "\(version.identifier)-\(platformFullString).\(Swiftly.currentPlatform.toolchainFileExtension)"
        )

        do {
            try await ctx.httpClient.getSwiftToolchainFile(toolchainFile).download(
                to: tmpFile,
                reportProgress: { progress in
                    let now = Date()

                    guard lastUpdate.distance(to: now) > 0.25 || progress.receivedBytes == progress.totalBytes
                    else {
                        return
                    }

                    let downloadedMiB = Double(progress.receivedBytes) / (1024.0 * 1024.0)
                    let totalMiB = Double(progress.totalBytes!) / (1024.0 * 1024.0)

                    lastUpdate = Date()

                    animation.update(
                        step: progress.receivedBytes,
                        total: progress.totalBytes!,
                        text:
                        "Downloaded \(String(format: "%.1f", downloadedMiB)) MiB of \(String(format: "%.1f", totalMiB)) MiB"
                    )
                }
            )
        } catch let notFound as DownloadNotFoundError {
            throw SwiftlyError(message: "\(version) does not exist at URL \(notFound.url), exiting")
        } catch {
            animation.complete(success: false)
            throw error
        }
        animation.complete(success: true)

        if verifySignature {
            try await Swiftly.currentPlatform.verifyToolchainSignature(
                ctx,
                toolchainFile: toolchainFile,
                archive: tmpFile,
                verbose: verbose
            )
        }

        try await Swiftly.currentPlatform.install(ctx, from: tmpFile, version: version, verbose: verbose)

        var pathChanged = false

        // Create proxies if we have a location where we can point them
        if let proxyTo = try? Swiftly.currentPlatform.findSwiftlyBin(ctx) {
            // Ensure swiftly doesn't overwrite any existing executables without getting confirmation first.
            let swiftlyBinDir = Swiftly.currentPlatform.swiftlyBinDir(ctx)
            let swiftlyBinDirContents =
                (try? FileManager.default.contentsOfDirectory(atPath: swiftlyBinDir.path)) ?? [String]()
            let toolchainBinDir = try await Swiftly.currentPlatform.findToolchainBinDir(ctx, version)
            let toolchainBinDirContents = try FileManager.default.contentsOfDirectory(
                atPath: toolchainBinDir.path)

            let existingProxies = swiftlyBinDirContents.filter { bin in
                do {
                    let linkTarget = try FileManager.default.destinationOfSymbolicLink(
                        atPath: swiftlyBinDir.appendingPathComponent(bin).path)
                    return linkTarget == proxyTo
                } catch { return false }
            }

            let overwrite = Set(toolchainBinDirContents).subtracting(existingProxies).intersection(
                swiftlyBinDirContents)
            if !overwrite.isEmpty && !assumeYes {
                await ctx.print("The following existing executables will be overwritten:")

                for executable in overwrite {
                    await ctx.print("  \(swiftlyBinDir.appendingPathComponent(executable).path)")
                }

                guard await ctx.promptForConfirmation(defaultBehavior: false) else {
                    throw SwiftlyError(message: "Toolchain installation has been cancelled")
                }
            }

            if verbose {
                await ctx.print("Setting up toolchain proxies...")
            }

            let proxiesToCreate = Set(toolchainBinDirContents).subtracting(swiftlyBinDirContents).union(
                overwrite)

            for p in proxiesToCreate {
                let proxy = Swiftly.currentPlatform.swiftlyBinDir(ctx).appendingPathComponent(p)

                if proxy.fileExists() {
                    try FileManager.default.removeItem(at: proxy)
                }

                try FileManager.default.createSymbolicLink(
                    atPath: proxy.path,
                    withDestinationPath: proxyTo
                )

                pathChanged = true
            }
        }

        config.installedToolchains.insert(version)

        try config.save(ctx)

        // If this is the first installed toolchain, mark it as in-use regardless of whether the
        // --use argument was provided.
        if useInstalledToolchain {
            try await Use.execute(ctx, version, globalDefault: false, &config)
        }

        // We always update the global default toolchain if there is none set. This could
        //  be the only toolchain that is installed, which makes it the only choice.
        if config.inUse == nil {
            config.inUse = version
            try config.save(ctx)
            await ctx.print("The global default toolchain has been set to `\(version)`")
        }

        await ctx.print("\(version) installed successfully!")
        return (postInstallScript, pathChanged)
    }

    /// Utilize the swift.org API along with the provided selector to select a toolchain for install.
    public static func resolve(_ ctx: SwiftlyCoreContext, config: Config, selector: ToolchainSelector)
        async throws -> ToolchainVersion
    {
        switch selector {
        case .latest:
            await ctx.print("Fetching the latest stable Swift release...")

            guard
                let release = try await ctx.httpClient.getReleaseToolchains(
                    platform: config.platform, limit: 1
                ).first
            else {
                throw SwiftlyError(message: "couldn't get latest releases")
            }
            return .stable(release)

        case let .stable(major, minor, patch):
            guard let minor else {
                throw SwiftlyError(
                    message:
                    "Need to provide at least major and minor versions when installing a release toolchain."
                )
            }

            if let patch {
                return .stable(ToolchainVersion.StableRelease(major: major, minor: minor, patch: patch))
            }

            await ctx.print("Fetching the latest stable Swift \(major).\(minor) release...")
            // If a patch was not provided, perform a lookup to get the latest patch release
            // of the provided major/minor version pair.
            let toolchain = try await ctx.httpClient.getReleaseToolchains(
                platform: config.platform, limit: 1
            ) { release in
                release.major == major && release.minor == minor
            }.first

            guard let toolchain else {
                throw SwiftlyError(message: "No release toolchain found matching \(major).\(minor)")
            }

            return .stable(toolchain)

        case let .snapshot(branch, date):
            if let date {
                return ToolchainVersion(snapshotBranch: branch, date: date)
            }

            await ctx.print("Fetching the latest \(branch) branch snapshot...")

            // If a date was not provided, perform a lookup to find the most recent snapshot
            // for the given branch.
            let snapshots: [ToolchainVersion.Snapshot]
            do {
                snapshots = try await ctx.httpClient.getSnapshotToolchains(
                    platform: config.platform, branch: branch, limit: 1
                ) { snapshot in
                    snapshot.branch == branch
                }
            } catch let branchNotFoundErr as SwiftlyHTTPClient.SnapshotBranchNotFoundError {
                throw SwiftlyError(
                    message:
                    "You have requested to install a snapshot toolchain from branch \(branchNotFoundErr.branch). It cannot be found on swift.org. Note that snapshots are only available from the current `main` release and the latest x.y (major.minor) release. Try again with a different branch."
                )
            } catch {
                throw error
            }

            let firstSnapshot = snapshots.first

            guard let firstSnapshot else {
                throw SwiftlyError(message: "No snapshot toolchain found for branch \(branch)")
            }

            return .snapshot(firstSnapshot)
        case .xcode:
            throw SwiftlyError(message: "xcode toolchains are not available from swift.org")
        }
    }
}
