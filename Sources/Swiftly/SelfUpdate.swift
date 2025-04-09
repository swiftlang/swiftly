import ArgumentParser
import Foundation
import TSCBasic
import TSCUtility

import SwiftlyCore

struct SelfUpdate: SwiftlyCommand {
    public static var configuration = CommandConfiguration(
        abstract: "Update the version of swiftly itself."
    )

    @OptionGroup var root: GlobalOptions

    private enum CodingKeys: String, CodingKey {
        case root
    }

    mutating func run() async throws {
        try await self.run(Swiftly.createDefaultContext())
    }

    mutating func run(_ ctx: SwiftlyCoreContext) async throws {
        let versionUpdateReminder = try await validateSwiftly(ctx)
        defer {
            versionUpdateReminder()
        }

        let swiftlyBin = Swiftly.currentPlatform.swiftlyBinDir(ctx).appendingPathComponent("swiftly")
        guard FileManager.default.fileExists(atPath: swiftlyBin.path) else {
            throw SwiftlyError(message: "Self update doesn't work when swiftly has been installed externally. Please keep it updated from the source where you installed it in the first place.")
        }

        let _ = try await Self.execute(ctx, verbose: self.root.verbose)
    }

    public static func execute(_ ctx: SwiftlyCoreContext, verbose: Bool) async throws -> SwiftlyVersion {
        ctx.print("Checking for swiftly updates...")

        let swiftlyRelease = try await ctx.httpClient.getCurrentSwiftlyRelease()

        guard try swiftlyRelease.swiftlyVersion > SwiftlyCore.version else {
            ctx.print("Already up to date.")
            return SwiftlyCore.version
        }

        var downloadURL: Foundation.URL?
        for platform in swiftlyRelease.platforms {
#if os(macOS)
            guard platform.isDarwin else {
                continue
            }
#elseif os(Linux)
            guard platform.isLinux else {
                continue
            }
#endif

#if arch(x86_64)
            downloadURL = try platform.x86_64URL
#elseif arch(arm64)
            downloadURL = try platform.arm64URL
#endif
        }

        guard let downloadURL else {
            throw SwiftlyError(message: "The newest release of swiftly is incompatible with your current OS and/or processor architecture.")
        }

        let version = try swiftlyRelease.swiftlyVersion

        ctx.print("A new version is available: \(version)")

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
            try await ctx.httpClient.downloadFile(
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

        try await Swiftly.currentPlatform.verifySignature(ctx, archiveDownloadURL: downloadURL, archive: tmpFile, verbose: verbose)
        try Swiftly.currentPlatform.extractSwiftlyAndInstall(ctx, from: tmpFile)

        ctx.print("Successfully updated swiftly to \(version) (was \(SwiftlyCore.version))")
        return version
    }
}
