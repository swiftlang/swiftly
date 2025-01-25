import ArgumentParser
import Foundation
import TSCBasic
import TSCUtility

import SwiftlyCore

internal struct SelfUpdate: SwiftlyCommand {
    public static var configuration = CommandConfiguration(
        abstract: "Update the version of swiftly itself."
    )

    @OptionGroup var root: GlobalOptions

    private enum CodingKeys: String, CodingKey {
        case root
    }

    internal mutating func run() async throws {
        try validateSwiftly()

        let swiftlyBin = Swiftly.currentPlatform.swiftlyBinDir.appendingPathComponent("swiftly")
        guard FileManager.default.fileExists(atPath: swiftlyBin.path) else {
            throw SwiftlyError(message: "Self update doesn't work when swiftly has been installed externally. Please keep it updated from the source where you installed it in the first place.")
        }

        let _ = try await Self.execute(verbose: self.root.verbose)
    }

    public static func execute(verbose: Bool) async throws -> SwiftlyVersion {
        SwiftlyCore.print("Checking for swiftly updates...")

        let swiftlyRelease = try await SwiftlyCore.httpClient.getCurrentSwiftlyRelease()
        guard let releaseVersion = try? SwiftlyVersion(parsing: swiftlyRelease.version) else {
            throw SwiftlyError(message: "Invalid swiftly version reported: \(swiftlyRelease.version)")
        }

        guard releaseVersion > SwiftlyCore.version else {
            SwiftlyCore.print("Already up to date.")
            return SwiftlyCore.version
        }

        var downloadURL: Foundation.URL?
        for platform in swiftlyRelease.platforms {
#if os(macOS)
            guard platform.platform.value1 == .darwin else {
                continue
            }
#elseif os(Linux)
            guard platform.platform.value1 == .linux else {
                continue
            }
#endif

#if arch(x86_64)
            guard let url = URL(string: platform.x8664) else {
                throw SwiftlyError(message: "The swiftly release URL is not valid: \(platform.x8664)")
            }
            downloadURL = url
#elseif arch(arm64)
            guard let url = URL(string: platform.arm64) else {
                throw SwiftlyError(message: "The swiftly release URL is not valid: \(platform.arm64)")
            }
            downloadURL = url
#endif
        }

        guard let downloadURL else {
            throw SwiftlyError(message: "No matching platform was found in swiftly release.")
        }

        SwiftlyCore.print("A new version is available: \(releaseVersion)")

        let tmpFile = Swiftly.currentPlatform.getTempFilePath()
        FileManager.default.createFile(atPath: tmpFile.path, contents: nil)
        defer {
            try? FileManager.default.removeItem(at: tmpFile)
        }

        let animation = PercentProgressAnimation(
            stream: stdoutStream,
            header: "Downloading swiftly \(releaseVersion)"
        )
        do {
            try await SwiftlyCore.httpClient.downloadFile(
                url: downloadURL,
                to: tmpFile,
                reportProgress: { progress in
                    let downloadedMiB = Double(progress.receivedBytes) / (1024.0 * 1024.0)
                    let totalMiB = Double(progress.totalBytes!) / (1024.0 * 1024.0)

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

        try await Swiftly.currentPlatform.verifySignature(httpClient: SwiftlyCore.httpClient, archiveDownloadURL: downloadURL, archive: tmpFile, verbose: verbose)
        try Swiftly.currentPlatform.extractSwiftlyAndInstall(from: tmpFile)

        SwiftlyCore.print("Successfully updated swiftly to \(releaseVersion) (was \(SwiftlyCore.version))")
        return releaseVersion
    }
}
