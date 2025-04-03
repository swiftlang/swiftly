import ArgumentParser
import SwiftlyCore

struct List: SwiftlyCommand {
    public static var configuration = CommandConfiguration(
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

    mutating func run() async throws {
        try await self.run(Swiftly.createDefaultContext())
    }

    mutating func run(_ ctx: SwiftlyCoreContext) async throws {
        try validateSwiftly(ctx)
        let selector = try self.toolchainSelector.map { input in
            try ToolchainSelector(parsing: input)
        }

        var config = try Config.load(ctx)

        let toolchains = config.listInstalledToolchains(selector: selector).sorted { $0 > $1 }
        let (inUse, _) = try await selectToolchain(ctx, config: &config)

        let printToolchain = { (toolchain: ToolchainVersion) in
            var message = "\(toolchain)"
            if let inUse, toolchain == inUse {
                message += " (in use)"
            }
            if toolchain == config.inUse {
                message += " (default)"
            }
            SwiftlyCore.print(ctx, message)
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

            let message = "Installed \(modifier) toolchains"
            SwiftlyCore.print(ctx, message)
            SwiftlyCore.print(ctx, String(repeating: "-", count: message.count))
            for toolchain in toolchains {
                printToolchain(toolchain)
            }
        } else {
            SwiftlyCore.print(ctx, "Installed release toolchains")
            SwiftlyCore.print(ctx, "----------------------------")
            for toolchain in toolchains {
                guard toolchain.isStableRelease() else {
                    continue
                }
                printToolchain(toolchain)
            }

            SwiftlyCore.print(ctx, "")
            SwiftlyCore.print(ctx, "Installed snapshot toolchains")
            SwiftlyCore.print(ctx, "-----------------------------")
            for toolchain in toolchains where toolchain.isSnapshot() {
                printToolchain(toolchain)
            }
        }
    }
}
