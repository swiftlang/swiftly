import ArgumentParser
import Foundation
import SwiftlyCore

struct ListAvailable: SwiftlyCommand {
    public static let configuration = CommandConfiguration(
        abstract: "List toolchains available for install."
    )

    @Argument(help: ArgumentHelp(
        "A filter to use when listing toolchains.",
        discussion: """

        The toolchain selector determines which toolchains to list. If no selector \
        is provided, all available release toolchains will be listed:

            $ swiftly list-available

        The available toolchains associated with a given major version can be listed by \
        specifying the major version as the selector: 

            $ swiftly list-available 5

        Likewise, the available toolchains associated with a given minor version can be listed \
        by specifying the minor version as the selector:

            $ swiftly list-available 5.2

        The installed snapshots for a given development branch can be listed by specifying the branch as the selector:

            $ swiftly list-available main-snapshot
            $ swiftly list-available x.y-snapshot

        Note that listing available snapshots before the latest release (major and minor number) is unsupported.
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

        let tc: [ToolchainVersion]

        switch selector {
        case let .snapshot(branch, _):
            do {
                tc = try await ctx.httpClient.getSnapshotToolchains(platform: config.platform, branch: branch).map { ToolchainVersion.snapshot($0) }
            } catch let branchNotFoundError as SwiftlyHTTPClient.SnapshotBranchNotFoundError {
                throw SwiftlyError(message: "The snapshot branch \(branchNotFoundError.branch) was not found on swift.org. Note that snapshot toolchains are only available for the current `main` release and the previous x.y (major.minor) release.")
            } catch {
                throw error
            }
        case .stable, .latest:
            tc = try await ctx.httpClient.getReleaseToolchains(platform: config.platform).map { ToolchainVersion.stable($0) }
        default:
            tc = try await ctx.httpClient.getReleaseToolchains(platform: config.platform).map { ToolchainVersion.stable($0) }
        }

        let toolchains = tc.filter { selector?.matches(toolchain: $0) ?? true }

        let installedToolchains = Set(config.listInstalledToolchains(selector: selector))
        let (inUse, _) = try await selectToolchain(ctx, config: &config)

        let filteredToolchains = selector == nil ? toolchains.filter { $0.isStableRelease() } : toolchains

        let availableToolchainInfos = filteredToolchains.compactMap { toolchain -> AvailableToolchainInfo? in
            AvailableToolchainInfo(
                version: toolchain,
                inUse: inUse == toolchain,
                isDefault: toolchain == config.inUse,
                installed: installedToolchains.contains(toolchain)
            )
        }

        try await ctx.output(AvailableToolchainsListInfo(toolchains: availableToolchainInfos, selector: selector))
    }
}
