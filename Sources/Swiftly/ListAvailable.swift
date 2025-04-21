import ArgumentParser
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

    private enum CodingKeys: String, CodingKey {
        case toolchainSelector
    }

    mutating func run() async throws {
        try await self.run(Swiftly.createDefaultContext())
    }

    mutating func run(_ ctx: SwiftlyCoreContext) async throws {
        try await validateSwiftly(ctx)
        let selector = try self.toolchainSelector.map { input in
            try ToolchainSelector(parsing: input)
        }

        var config = try await Config.load(ctx)

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

        let printToolchain = { (toolchain: ToolchainVersion) in
            var message = "\(toolchain)"
            if installedToolchains.contains(toolchain) {
                message += " (installed)"
            }
            if let inUse, toolchain == inUse {
                message += " (in use)"
            }
            if toolchain == config.inUse {
                message += " (default)"
            }
            await ctx.print(message)
        }

        if let selector {
            let modifier = switch selector {
            case let .stable(major, minor, nil):
                if let minor {
                    "Swift \(major).\(minor) release"
                } else {
                    "Swift \(major) release"
                }
            case .snapshot(.main, nil):
                "main development snapshot"
            case let .snapshot(.release(major, minor), nil):
                "\(major).\(minor) development snapshot"
            default:
                "matching"
            }

            let message = "Available \(modifier) toolchains"
            await ctx.print(message)
            await ctx.print(String(repeating: "-", count: message.count))
            for toolchain in toolchains {
                await printToolchain(toolchain)
            }
        } else {
            print("Available release toolchains")
            print("----------------------------")
            for toolchain in toolchains where toolchain.isStableRelease() {
                await printToolchain(toolchain)
            }
        }
    }
}
