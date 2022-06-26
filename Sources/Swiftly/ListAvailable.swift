import ArgumentParser
import SwiftlyCore

struct ListAvailable: AsyncParsableCommand {
    @Argument(help: "A filter to use when listing toolchains.")
    var toolchainSelector: String?

    internal mutating func run() async throws {
        let selector = try self.toolchainSelector.map { input in
            try ToolchainSelector(parsing: input)
        }

        let toolchains = try await HTTP().getLatestReleases()
            .compactMap { (try? $0.parse()).map(ToolchainVersion.stable) }
            .filter { selector?.matches(toolchain: $0) ?? true }

        let installedToolchains = Set(currentPlatform.listToolchains(selector: selector))
        let activeToolchain = try currentPlatform.currentToolchain()

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
