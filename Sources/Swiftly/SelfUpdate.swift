import ArgumentParser
import Foundation
import TSCBasic
import TSCUtility

import SwiftlyCore

internal struct SelfUpdate: SwiftlyCommand {
    public static var configuration = CommandConfiguration(
        abstract: "Update the version of swiftly itself."
    )

    private enum CodingKeys: CodingKey {}

    internal mutating func run() async throws {
        try validateSwiftly()

        let swiftlyBin = Swiftly.currentPlatform.swiftlyBinDir.appendingPathComponent("swiftly")
        guard FileManager.default.fileExists(atPath: swiftlyBin.path) else {
            throw Error(message: "Self update doesn't work when swiftly has been installed externally. Please keep it updated from the source where you installed it in the first place.")
        }

        let _ = try await Self.execute()
    }

    public static func execute() async throws -> SwiftlyVersion {
        SwiftlyCore.print("Checking for swiftly updates...")

        let swiftlyRelease = try await SwiftlyCore.httpClient.getSwiftlyRelease()

        guard swiftlyRelease.version > SwiftlyCore.version else {
            SwiftlyCore.print("Already up to date.")
            return SwiftlyCore.version
        }

        var downloadURL: Foundation.URL?
        for platform in swiftlyRelease.platforms {
#if os(macOS)
            guard platform.platform == .Darwin else {
                continue
            }
#elseif os(Linux)
            guard platform.platform == .Linux else {
                continue
            }
#endif

#if arch(x86_64)
            downloadURL = platform.x86_64
#elseif arch(arm64)
            downloadURL = platform.arm64
#endif
        }

        guard let downloadURL = downloadURL else {
            throw Error(message: "The newest release of swiftly is incompatible with your current OS and/or processor architecture.")
        }

        let version = swiftlyRelease.version

        SwiftlyCore.print("A new version is available: \(version)")

        let tmpFile = Swiftly.currentPlatform.getTempFilePath()
        FileManager.default.createFile(atPath: tmpFile.path, contents: nil)
        defer {
            try? FileManager.default.removeItem(at: tmpFile)
        }

        let animation = PercentProgressAnimation(
            stream: stdoutStream,
            header: "Downloading swiftly \(version)"
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

        try await Swiftly.currentPlatform.verifySignature(httpClient: SwiftlyCore.httpClient, archiveDownloadURL: downloadURL, archive: tmpFile)
        try Swiftly.currentPlatform.extractSwiftlyAndInstall(from: tmpFile)

        SwiftlyCore.print("Successfully updated swiftly to \(version) (was \(SwiftlyCore.version))")
        return version
    }
}
