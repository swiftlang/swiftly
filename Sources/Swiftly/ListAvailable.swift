import ArgumentParser
import SwiftlyCore

struct ListAvailable: AsyncParsableCommand {
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
            $ swiftly list-available 5.7-snapshot
        """
    ))
    var toolchainSelector: String?

    internal mutating func run() async throws {
        let selector = try self.toolchainSelector.map { input in
            try ToolchainSelector(parsing: input)
        }

        let toolchains = try await HTTP.getLatestReleases()
            .compactMap { (try? $0.parse()).map(ToolchainVersion.stable) }
            .filter { selector?.matches(toolchain: $0) ?? true }

        let installedToolchains = Set(Swiftly.currentPlatform.listToolchains(selector: selector))
        let activeToolchain = try Swiftly.currentPlatform.currentToolchain()

        let printToolchain = { (toolchain: ToolchainVersion) in
            var message = "\(toolchain)"
            if toolchain == activeToolchain {
                message += " (installed, in use)"
            } else if installedToolchains.contains(toolchain) {
                message += " (installed)"
            }
            print(message)
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

            let message = "available \(modifier) toolchains"
            print(message)
            print(String(repeating: "-", count: message.utf8.count))
            for toolchain in toolchains {
                printToolchain(toolchain)
            }
        } else {
            print("available release toolchains")
            print("----------------------------")
            for toolchain in toolchains where toolchain.isStableRelease() {
                printToolchain(toolchain)
            }

            print("")
            print("available snapshot toolchains")
            print("-----------------------------")
            for toolchain in toolchains where toolchain.isSnapshot() {
                printToolchain(toolchain)
            }
        }
    }
}
