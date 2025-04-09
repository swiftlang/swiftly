import ArgumentParser
import Foundation
import SwiftlyCore

struct Link: SwiftlyCommand {
    public static var configuration = CommandConfiguration(
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
        try validateSwiftly(ctx)

        var config = try Config.load(ctx)
        let toolchainVersion = try await Install.determineToolchainVersion(
            ctx,
            version: nil,
            config: &config
        )

        let pathChanged = try Install.setupProxies(
            ctx,
            version: toolchainVersion,
            verbose: self.root.verbose,
            assumeYes: self.root.assumeYes
        )

        if pathChanged {
            ctx.print(Messages.refreshShell)
        }
    }
}
