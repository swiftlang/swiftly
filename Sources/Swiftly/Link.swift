import ArgumentParser
import Foundation
import SwiftlyCore

struct Link: SwiftlyCommand {
    public static let configuration = CommandConfiguration(
        abstract: "Link swiftly so it resumes management of the active toolchain."
    )

    @Argument(help: ArgumentHelp(
        "Links swiftly if it has been disabled.",
        discussion: """

        Links swiftly if it has been disabled.
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

        var config = try await Config.load(ctx)
        let toolchainVersion = try await Install.determineToolchainVersion(
            ctx,
            version: config.inUse?.name,
            config: &config
        )

        let pathChanged = try await Install.setupProxies(
            ctx,
            version: toolchainVersion,
            verbose: self.root.verbose,
            assumeYes: self.root.assumeYes
        )

        if pathChanged {
            await ctx.message("""
            Linked swiftly to Swift \(toolchainVersion.name).

            \(Messages.refreshShell)
            """)
        } else {
            await ctx.message("""
            Swiftly is already linked to Swift \(toolchainVersion.name).
            """)
        }
    }
}
