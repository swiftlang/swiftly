import ArgumentParser
import Foundation
import SwiftlyCore

struct List: SwiftlyCommand {
    public static let configuration = CommandConfiguration(
        abstract: "List installed toolchains."
    )

    @Argument(help: ArgumentHelp(
        "A filter to use when listing toolchains.",
        discussion: """

        The toolchain selector determines which toolchains to list. If no selector \
        is provided, all installed toolchains will be listed:

            $ swiftly list

        The installed toolchains associated with a given major version can be listed by \
        specifying the major version as the selector: 

            $ swiftly list 5

        Likewise, the installed toolchains associated with a given minor version can be listed \
        by specifying the minor version as the selector:

            $ swiftly list 5.2

        The installed snapshots for a given development branch can be listed by specifying the branch as the selector:

            $ swiftly list main-snapshot
            $ swiftly list 5.7-snapshot
        """
    ))
    var toolchainSelector: String?

    @Option(name: .long, help: "Output format (text, json)")
    var format: SwiftlyCore.OutputFormat = .text

    mutating func run() async throws {
        try await self.run(Swiftly.createDefaultContext(format: self.format))
    }

    mutating func run(_ ctx: SwiftlyCoreContext) async throws {
        let versionUpdateReminder = try await validateSwiftly(ctx)
        defer {
            versionUpdateReminder()
        }

        var config = try await Config.load(ctx)
        let selector = try self.toolchainSelector.map { input in
            try ToolchainSelector(parsing: input)
        }

        let toolchains = config.listInstalledToolchains(selector: selector).sorted { $0 > $1 }
        let (inUse, _) = try await selectToolchain(ctx, config: &config)

        let installedToolchainInfos = toolchains.compactMap { toolchain -> InstallToolchainInfo? in
            InstallToolchainInfo(
                version: toolchain,
                inUse: inUse == toolchain,
                isDefault: toolchain == config.inUse
            )
        }

        try await ctx.output(InstalledToolchainsListInfo(toolchains: installedToolchainInfos, selector: selector))
    }
}
