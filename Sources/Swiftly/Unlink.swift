import ArgumentParser
import SwiftlyCore
import Foundation

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
        try validateSwiftly(ctx)

        if let proxyTo = try? Swiftly.currentPlatform.findSwiftlyBin(ctx) {
            let swiftlyBinDir = Swiftly.currentPlatform.swiftlyBinDir(ctx)
            let swiftlyBinDirContents = (try? FileManager.default.contentsOfDirectory(atPath: swiftlyBinDir.path)) ?? [String]()

            let existingProxies = swiftlyBinDirContents.filter { bin in
                do {
                    let linkTarget = try FileManager.default.destinationOfSymbolicLink(atPath: swiftlyBinDir.appendingPathComponent(bin).path)
                    return linkTarget == proxyTo
                } catch { return false }
            }

            for p in existingProxies {
                let proxy = Swiftly.currentPlatform.swiftlyBinDir(ctx).appendingPathComponent(p)

                if proxy.fileExists() {
                    try FileManager.default.removeItem(at: proxy)
                }
            }
        }
    }
}
