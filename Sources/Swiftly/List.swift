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

        The installed snapshots for a given devlopment branch can be listed by specifying the branch as the selector:

            $ swiftly list main-snapshot
            $ swiftly list 5.7-snapshot
        """
    ))
    var toolchainSelector: String?

    @Flag(name: .shortAndLong, help: "Print the location of the toolchains prefixed with the version <x.y.z> - <path/to/toolchain>.")
    var printLocation: Bool = false

    internal mutating func run() async throws {
        try validateSwiftly()
        let selector = try self.toolchainSelector.map { input in
            try ToolchainSelector(parsing: input)
        }

        var config = try Config.load()

        let toolchains = config.listInstalledToolchains(selector: selector).sorted { $0 > $1 }

        guard !self.printLocation else {
            for toolchain in toolchains {
                SwiftlyCore.print("\(toolchain.name) - \(Swiftly.currentPlatform.findToolchainLocation(toolchain).path)")
            }

            return
        }
        let (inUse, _) = try await selectToolchain(config: &config)

        let printToolchain = { (toolchain: ToolchainVersion) in
            var message = "\(toolchain)"
            if let inUse = inUse, toolchain == inUse {
                message += " (in use)"
            }
            if toolchain == config.inUse {
                message += " (default)"
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

            let message = "Installed \(modifier) toolchains"
            SwiftlyCore.print(message)
            SwiftlyCore.print(String(repeating: "-", count: message.count))
            for toolchain in toolchains {
                printToolchain(toolchain)
            }
        } else {
            SwiftlyCore.print("Installed release toolchains")
            SwiftlyCore.print("----------------------------")
            for toolchain in toolchains {
                guard toolchain.isStableRelease() else {
                    continue
                }
                printToolchain(toolchain)
            }

            SwiftlyCore.print("")
            SwiftlyCore.print("Installed snapshot toolchains")
            SwiftlyCore.print("-----------------------------")
            for toolchain in toolchains where toolchain.isSnapshot() {
                printToolchain(toolchain)
            }
        }
    }
}
