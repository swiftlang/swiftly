import _StringProcessing
import ArgumentParser
import Foundation
import TSCUtility
import TSCBasic

import SwiftlyCore

struct Install: AsyncParsableCommand {
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
        """
    ))

    var version: String

    mutating func run() async throws {
        let selector = try ToolchainSelector(parsing: self.version)
        let toolchainVersion = try await self.resolve(selector: selector)
        print("Installing \(toolchainVersion)")

        try await Self.execute(version: toolchainVersion)

        print("\(toolchainVersion) installed successfully!")
    }

    internal static func execute(version: ToolchainVersion) async throws {
        let tmpFile = Swiftly.currentPlatform.getTempFilePath()

        var url: String = "https://download.swift.org/"
        switch version {
        case let .stable(stableVersion):
            // Building URL path that looks like:
            // swift-5.6.2-release/ubuntu2004/swift-5.6.2-RELEASE/swift-5.6.2-RELEASE-ubuntu20.04.tar.gz
            var versionString = "\(stableVersion.major).\(stableVersion.minor)"
            if stableVersion.patch != 0 {
                versionString += ".\(stableVersion.patch)"
            }
            url += "swift-\(versionString)-release/"
            url += "\(Swiftly.currentPlatform.name)/"
            url += "swift-\(versionString)-RELEASE/"
            url += "swift-\(versionString)-RELEASE-\(Swiftly.currentPlatform.fullName).\(Swiftly.currentPlatform.toolchainFileExtension)"
        case let .snapshot(branch, date):
            // Building URL path that looks like:
            // development/ubuntu1804/swift-DEVELOPMENT-SNAPSHOT-2022-08-24-a/swift-DEVELOPMENT-SNAPSHOT-2022-08-24-a-ubuntu18.04.tar.gz


            let snapshotString: String
            switch branch {
            case let .release(major, minor):
                url += "swift-\(major).\(minor)-branch/"
                snapshotString = "swift-\(major).\(minor)-DEVELOPMENT-SNAPSHOT"
            case .main:
                url += "development/"
                snapshotString = "swift-DEVELOPMENT-SNAPSHOT"
            }

            url += "\(Swiftly.currentPlatform.name)/"
            url += "\(snapshotString)-\(date)-a/"
            url += "\(snapshotString)-\(date)-a-\(Swiftly.currentPlatform.fullName).\(Swiftly.currentPlatform.toolchainFileExtension)"
        }

        let animation = PercentProgressAnimation(
            stream: stdoutStream,
            header: "Downloading \(version)"
        )

        var lastUpdate = Date()

        do {
            try await HTTP.downloadFile(
                url: url,
                to: tmpFile.path,
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
        } catch {
            animation.complete(success: false)
            throw error
        }

        animation.complete(success: true)

        try Swiftly.currentPlatform.install(from: tmpFile, version: version)
    }

    /// Utilize the GitHub API along with the provided selector to select a toolchain for install.
    /// TODO: update this to use an official Apple API
    func resolve(selector: ToolchainSelector) async throws -> ToolchainVersion {
        switch selector {
        case .latest:
            // get the latest stable release
            guard let release = try await HTTP.getLatestReleases(numberOfReleases: 1).first else {
                throw Error(message: "couldnt get latest releases")
            }
            return try .stable(release.parse())

        case let .stable(major, minor, patch):
            guard let minor else {
                throw Error(message: "Need to provide at least major and minor versions when installing a release toolchain.")
            }

            if let patch {
                return .stable(ToolchainVersion.StableRelease(major: major, minor: minor, patch: patch))
            }

            // if no patch was provided, perform a network lookup to get the latest patch release
            // of the provided major/minor version pair.
            for release in try await HTTP.getLatestReleases() {
                let parsed = try release.parse()
                guard
                    parsed.major == major,
                    parsed.minor == minor
                else {
                    continue
                }
                return .stable(parsed)
            }

            throw Error(message: "No release found matching \(major).\(minor)")

        case let .snapshot(branch, date):
            if let date {
                return .snapshot(branch: branch, date: date)
            }
            // TODO: get latest snapshot if no date provided
            throw Error(message: "TODO get latest snapshot")
        }
    }
}
