import ArgumentParser
import Foundation
import SwiftlyCore
import SystemPackage

struct Unlink: SwiftlyCommand {
    public static let configuration = CommandConfiguration(
        abstract: "Unlinks swiftly so it no longer manages the active toolchain."
    )

    @Argument(help: ArgumentHelp(
        "Unlinks swiftly, allowing the system default toolchain to be used.",
        discussion: """

        Unlinks swiftly until swiftly is linked again with:

            $ swiftly link
        """
    ))
    var toolchainSelector: String?

    @OptionGroup var root: GlobalOptions

    mutating func run() async throws {
        try await self.run(Swiftly.createDefaultContext())
    }

    mutating func run(_ ctx: SwiftlyCoreContext) async throws {
        let versionUpdateReminder = try await validateSwiftly(ctx)
        defer {
            versionUpdateReminder()
        }

        var pathChanged = false
        if let proxyTo = try? await Swiftly.currentPlatform.findSwiftlyBin(ctx) {
            let swiftlyBinDir = Swiftly.currentPlatform.swiftlyBinDir(ctx)
            let swiftlyBinDirContents = (try? FileManager.default.contentsOfDirectory(atPath: swiftlyBinDir.string)) ?? [String]()

            let existingProxies = swiftlyBinDirContents.filter { bin in
                do {
                    let linkTarget = try FileManager.default.destinationOfSymbolicLink(atPath: (swiftlyBinDir / bin).string)
                    return linkTarget == proxyTo.string
                } catch { return false }
            }

            for p in existingProxies {
                let proxy = Swiftly.currentPlatform.swiftlyBinDir(ctx) / p

                if try await fs.exists(atPath: proxy) {
                    try await fs.remove(atPath: proxy)
                    pathChanged = true
                }
            }
        }

        if pathChanged {
            await ctx.print(Messages.refreshShell)
        }
    }
}
