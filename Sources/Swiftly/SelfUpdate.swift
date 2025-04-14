import ArgumentParser
import Foundation
import SwiftlyCore
@preconcurrency import TSCBasic
import TSCUtility

struct SelfUpdate: SwiftlyCommand {
    public static let configuration = CommandConfiguration(
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
        try await validateSwiftly(ctx)

        let swiftlyBin = Swiftly.currentPlatform.swiftlyBinDir(ctx) / "swiftly"
        guard try await fileExists(atPath: swiftlyBin) else {
            throw SwiftlyError(
                message:
                "Self update doesn't work when swiftly has been installed externally. Please keep it updated from the source where you installed it in the first place."
            )
        }

        let _ = try await Self.execute(ctx, verbose: self.root.verbose)
    }

    public static func execute(_ ctx: SwiftlyCoreContext, verbose: Bool) async throws
        -> SwiftlyVersion
    {
        await ctx.print("Checking for swiftly updates...")

        let swiftlyRelease = try await ctx.httpClient.getCurrentSwiftlyRelease()

        guard try swiftlyRelease.swiftlyVersion > SwiftlyCore.version else {
            await ctx.print("Already up to date.")
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
            throw SwiftlyError(
                message:
                "The newest release of swiftly is incompatible with your current OS and/or processor architecture."
            )
        }

        let version = try swiftlyRelease.swiftlyVersion

        await ctx.print("A new version is available: \(version)")

        let tmpFile = mktemp()
        try await create(file: tmpFile, contents: nil)
        return try await withTemporary(files: tmpFile) {
            let animation = PercentProgressAnimation(
                stream: stdoutStream,
                header: "Downloading swiftly \(version)"
            )
            do {
                try await ctx.httpClient.getSwiftlyRelease(url: downloadURL).download(
                    to: tmpFile,
                    reportProgress: { progress in
                        let downloadedMiB = Double(progress.receivedBytes) / (1024.0 * 1024.0)
                        let totalMiB = Double(progress.totalBytes!) / (1024.0 * 1024.0)

                        animation.update(
                            step: progress.receivedBytes,
                            total: progress.totalBytes!,
                            text:
                            "Downloaded \(String(format: "%.1f", downloadedMiB)) MiB of \(String(format: "%.1f", totalMiB)) MiB"
                        )
                    }
                )
            } catch {
                animation.complete(success: false)
                throw error
            }
            animation.complete(success: true)

            try await Swiftly.currentPlatform.verifySwiftlySignature(
                ctx, archiveDownloadURL: downloadURL, archive: tmpFile, verbose: verbose
            )
            try await Swiftly.currentPlatform.extractSwiftlyAndInstall(ctx, from: tmpFile)

            await ctx.print("Successfully updated swiftly to \(version) (was \(SwiftlyCore.version))")
            return version
        }
    }
}
