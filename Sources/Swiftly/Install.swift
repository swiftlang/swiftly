import _StringProcessing
import ArgumentParser
import Foundation
import TSCBasic
import TSCUtility

import SwiftlyCore

struct Install: SwiftlyCommand {
    public static var configuration = CommandConfiguration(
        abstract: "Install a new toolchain."
    )

    @Argument(help: ArgumentHelp(
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

         Install whatever toolchain is current selected, such as a .swift-version file:

            $ swiftly install
        """
    ))
    var version: String?

    @Flag(name: .shortAndLong, help: "Mark the newly installed toolchain as in-use.")
    var use: Bool = false

    @Option(help: ArgumentHelp(
        "A GitHub authentication token to use for any GitHub API requests.",
        discussion: """
        This is useful to avoid GitHub's low rate limits. If an installation
        fails with an \"unauthorized\" status code, it likely means the rate limit has been hit.
        """
    ))
    var token: String?

    @Flag(inversion: .prefixedNo, help: "Verify the toolchain's PGP signature before proceeding with installation.")
    var verify = true

    @Option(help: ArgumentHelp(
        "A file path to a location for a post installation script",
        discussion: """
        If the toolchain that is installed has extra post installation steps they they will be
        written to this file as commands that can be run after the installation.
        """
    ))
    var postInstallFile: String?

    private enum CodingKeys: String, CodingKey {
        case version, token, use, verify, postInstallFile
    }

    mutating func run() async throws {
        try validateSwiftly()

        var config = try Config.load()

        var selector: ToolchainSelector

        if let version = self.version {
            selector = try ToolchainSelector(parsing: version)
        } else {
            if case let (_, result) = try await selectToolchain(config: &config),
               case let .swiftVersionFile(_, sel, error) = result
            {
                if let sel = sel {
                    selector = sel
                } else if let error = error {
                    throw error
                } else {
                    throw Error(message: "Internal error selecting toolchain to install.")
                }
            } else {
                throw Error(message: "There is no toolchain selected from a .swift-version file to install.")
            }
        }

        SwiftlyCore.httpClient.githubToken = self.token
        let toolchainVersion = try await Self.resolve(config: config, selector: selector)
        let postInstallScript = try await Self.execute(
            version: toolchainVersion,
            &config,
            useInstalledToolchain: self.use,
            verifySignature: self.verify
        )

        if let postInstallScript = postInstallScript {
            guard let postInstallFile = self.postInstallFile else {
                throw Error(message: """

                There are some system dependencies that should be installed before using this toolchain.
                You can run the following script as the system administrator (e.g. root) to prepare
                your system:

                \(postInstallScript)
                """)
            }

            try Data(postInstallScript.utf8).write(to: URL(fileURLWithPath: postInstallFile), options: .atomic)
        }
    }

    public static func execute(
        version: ToolchainVersion,
        _ config: inout Config,
        useInstalledToolchain: Bool,
        verifySignature: Bool
    ) async throws -> String? {
        guard !config.installedToolchains.contains(version) else {
            SwiftlyCore.print("\(version) is already installed.")
            return nil
        }

        // Ensure the system is set up correctly before downloading it. Problems that prevent installation
        //  will throw, while problems that prevent use of the toolchain will be written out as a post install
        //  script for the user to run afterwards.
        let postInstallScript = try await Swiftly.currentPlatform.verifySystemPrerequisitesForInstall(httpClient: SwiftlyCore.httpClient, platformName: config.platform.name, version: version, requireSignatureValidation: verifySignature)

        SwiftlyCore.print("Installing \(version)")

        let tmpFile = Swiftly.currentPlatform.getTempFilePath()
        FileManager.default.createFile(atPath: tmpFile.path, contents: nil)
        defer {
            try? FileManager.default.removeItem(at: tmpFile)
        }

        var url = "https://download.swift.org/"

        var platformString = config.platform.name
        var platformFullString = config.platform.nameFull

#if !os(macOS) && arch(arm64)
        platformString += "-aarch64"
        platformFullString += "-aarch64"
#endif

        switch version {
        case let .stable(stableVersion):
            // Building URL path that looks like:
            // swift-5.6.2-release/ubuntu2004/swift-5.6.2-RELEASE/swift-5.6.2-RELEASE-ubuntu20.04.tar.gz
            var versionString = "\(stableVersion.major).\(stableVersion.minor)"
            if stableVersion.patch != 0 {
                versionString += ".\(stableVersion.patch)"
            }

            url += "swift-\(versionString)-release/"
        case let .snapshot(release):
            switch release.branch {
            case let .release(major, minor):
                url += "swift-\(major).\(minor)-branch/"
            case .main:
                url += "development/"
            }
        }

        url += "\(platformString)/"
        url += "\(version.identifier)/"
        url += "\(version.identifier)-\(platformFullString).\(Swiftly.currentPlatform.toolchainFileExtension)"

        guard let url = URL(string: url) else {
            throw Error(message: "Invalid toolchain URL: \(url)")
        }

        let animation = PercentProgressAnimation(
            stream: stdoutStream,
            header: "Downloading \(version)"
        )

        var lastUpdate = Date()

        do {
            try await SwiftlyCore.httpClient.downloadFile(
                url: url,
                to: tmpFile,
                reportProgress: { progress in
                    let now = Date()

                    guard lastUpdate.distance(to: now) > 0.25 || progress.receivedBytes == progress.totalBytes else {
                        return
                    }

                    let downloadedMiB = Double(progress.receivedBytes) / (1024.0 * 1024.0)
                    let totalMiB = Double(progress.totalBytes!) / (1024.0 * 1024.0)

                    lastUpdate = Date()

                    animation.update(
                        step: progress.receivedBytes,
                        total: progress.totalBytes!,
                        text: "Downloaded \(String(format: "%.1f", downloadedMiB)) MiB of \(String(format: "%.1f", totalMiB)) MiB"
                    )
                }
            )
        } catch let notFound as SwiftlyHTTPClient.DownloadNotFoundError {
            throw Error(message: "\(version) does not exist at URL \(notFound.url), exiting")
        } catch {
            animation.complete(success: false)
            throw error
        }
        animation.complete(success: true)

        if verifySignature {
            try await Swiftly.currentPlatform.verifySignature(
                httpClient: SwiftlyCore.httpClient,
                archiveDownloadURL: url,
                archive: tmpFile
            )
        }

        try Swiftly.currentPlatform.install(from: tmpFile, version: version)

        config.installedToolchains.insert(version)

        try config.save()

        // If this is the first installed toolchain, mark it as in-use regardless of whether the
        // --use argument was provided.
        if useInstalledToolchain || config.inUse == nil {
            // TODO: consider adding the global default option to this commands flags
            try await Use.execute(version, false, &config)
        }

        SwiftlyCore.print("\(version) installed successfully!")
        return postInstallScript
    }

    /// Utilize the GitHub API along with the provided selector to select a toolchain for install.
    /// TODO: update this to use an official swift.org API
    public static func resolve(config: Config, selector: ToolchainSelector) async throws -> ToolchainVersion {
        switch selector {
        case .latest:
            SwiftlyCore.print("Fetching the latest stable Swift release...")

            guard let release = try await SwiftlyCore.httpClient.getReleaseToolchains(platform: config.platform, limit: 1).first else {
                throw Error(message: "couldn't get latest releases")
            }
            return .stable(release)

        case let .stable(major, minor, patch):
            guard let minor else {
                throw Error(
                    message: "Need to provide at least major and minor versions when installing a release toolchain."
                )
            }

            if let patch {
                return .stable(ToolchainVersion.StableRelease(major: major, minor: minor, patch: patch))
            }

            SwiftlyCore.print("Fetching the latest stable Swift \(major).\(minor) release...")
            // If a patch was not provided, perform a lookup to get the latest patch release
            // of the provided major/minor version pair.
            let toolchain = try await SwiftlyCore.httpClient.getReleaseToolchains(platform: config.platform, limit: 1) { release in
                release.major == major && release.minor == minor
            }.first

            guard let toolchain else {
                throw Error(message: "No release toolchain found matching \(major).\(minor)")
            }

            return .stable(toolchain)

        case let .snapshot(branch, date):
            if let date {
                return ToolchainVersion(snapshotBranch: branch, date: date)
            }

            SwiftlyCore.print("Fetching the latest \(branch) branch snapshot...")
            // If a date was not provided, perform a lookup to find the most recent snapshot
            // for the given branch.
            let snapshot = try await SwiftlyCore.httpClient.getSnapshotToolchains(platform: config.platform, branch: branch, limit: 1) { snapshot in
                snapshot.branch == branch
            }.first

            guard let snapshot else {
                throw Error(message: "No snapshot toolchain found for branch \(branch)")
            }

            return .snapshot(snapshot)
        }
    }
}
