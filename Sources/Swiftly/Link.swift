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
        var config = try validatedConfig(ctx)
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
            await ctx.print("""
            Linked swiftly to \(toolchainVersion.name).

            \(Messages.refreshShell)
            """)
        }
    }
}
