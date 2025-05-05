import ArgumentParser
import Foundation
import SwiftlyCore

struct SelfUninstall: SwiftlyCommand {
    public static let configuration = CommandConfiguration(
        abstract: "Uninstall swiftly itself.",
    )

    @OptionGroup var root: GlobalOptions

    private enum CodingKeys: String, CodingKey {
        case root
    }

    mutating func run() async throws {
        try await self.run(Swiftly.createDefaultContext())
    }

    mutating func run(_ ctx: SwiftlyCoreContext) async throws {
        let _ = try await validateSwiftly(ctx)
        let swiftlyBin = Swiftly.currentPlatform.swiftlyBinDir(ctx)

        guard try await fs.exists(atPath: swiftlyBin) else {
            throw SwiftlyError(
                message:
                "Self uninstall doesn't work when swiftly has been installed externally. Please uninstall it from the source where you installed it in the first place."
            )
        }

        try await Self.execute(ctx, verbose: self.root.verbose)
    }

    public static func execute(_ ctx: SwiftlyCoreContext, verbose _: Bool) async throws {
        await ctx.print("""
        You are about to uninstall swiftly. 
        This will remove the swiftly binary and all the files in the swiftly home directory. 
        This action is irreversible.
        """)

        guard await ctx.promptForConfirmation(defaultBehavior: true) else {
            throw SwiftlyError(message: "swiftly installation has been cancelled")
        }
        await ctx.print("Uninstalling swiftly...")

        let swiftlyBin = Swiftly.currentPlatform.swiftlyBinDir(ctx)
        let swiftlyHome = Swiftly.currentPlatform.swiftlyHomeDir(ctx)

        await ctx.print("Removing swiftly binary from \(swiftlyBin)...")
        try await fs.remove(atPath: swiftlyBin)

        await ctx.print("Removing swiftly home directory from \(swiftlyHome)...")
        try await fs.remove(atPath: swiftlyHome)

        await ctx.print("Swiftly uninstalled successfully.")
    }
}
