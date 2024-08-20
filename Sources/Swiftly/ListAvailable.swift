import ArgumentParser
import SwiftlyCore

struct ListAvailable: SwiftlyCommand {
    public static var configuration = CommandConfiguration(
        abstract: "List toolchains available for install."
    )

    @Argument(help: ArgumentHelp(
        "A filter to use when listing toolchains.",
        discussion: """

        The toolchain selector determines which toolchains to list. If no selector \
        is provided, all available toolchains will be listed:

            $ swiftly list-available

        The available toolchains associated with a given major version can be listed by \
        specifying the major version as the selector: 

            $ swiftly list-available 5

        Likewise, the available toolchains associated with a given minor version can be listed \
        by specifying the minor version as the selector:

            $ swiftly list-available 5.2

        The installed snapshots for a given devlopment branch can be listed by specifying the branch as the selector:

            $ swiftly list-available main-snapshot
            $ swiftly list-available 6.0-snapshot

        Note that listing available snapshots before 6.0 is unsupported.
        """
    ))
    var toolchainSelector: String?

    private enum CodingKeys: String, CodingKey {
        case toolchainSelector
    }

    internal mutating func run() async throws {
        try validateSwiftly()
        let selector = try self.toolchainSelector.map { input in
            try ToolchainSelector(parsing: input)
        }

        let config = try Config.load()

        let tc: [ToolchainVersion]

        switch selector {
        case let .snapshot(branch, _):
            if case let .release(major, _) = branch, major < 6 {
                throw Error(message: "Listing available snapshots previous to 6.0 is not supported.")
            }

            tc = try await SwiftlyCore.httpClient.getSnapshotToolchains(platform: config.platform, branch: branch).map { ToolchainVersion.snapshot($0) }
        default:
            tc = try await SwiftlyCore.httpClient.getReleaseToolchains(platform: config.platform).map { ToolchainVersion.stable($0) }
        }

        let toolchains = tc.filter { selector?.matches(toolchain: $0) ?? true }

        let installedToolchains = Set(config.listInstalledToolchains(selector: selector))
        let activeToolchain = config.inUse

        let printToolchain = { (toolchain: ToolchainVersion) in
            var message = "\(toolchain)"
            if toolchain == activeToolchain {
                message += " (installed, in use)"
            } else if installedToolchains.contains(toolchain) {
                message += " (installed)"
            }
            SwiftlyCore.print(message)
        }

        if let selector {
            let modifier: String
            switch selector {
            case let .stable(major, minor, nil):
                if let minor {
                    modifier = "Swift \(major).\(minor) release"
                } else {
                    modifier = "Swift \(major) release"
                }
            case .snapshot(.main, nil):
                modifier = "main development snapshot"
            case let .snapshot(.release(major, minor), nil):
                modifier = "\(major).\(minor) development snapshot"
            default:
                modifier = "matching"
            }

            let message = "Available \(modifier) toolchains"
            SwiftlyCore.print(message)
            SwiftlyCore.print(String(repeating: "-", count: message.count))
            for toolchain in toolchains {
                printToolchain(toolchain)
            }
        } else {
            print("Available release toolchains")
            print("----------------------------")
            for toolchain in toolchains where toolchain.isStableRelease() {
                printToolchain(toolchain)
            }
        }
    }
}
