import ArgumentParser
import SwiftlyCore

struct List: ParsableCommand {
    @Argument(help: "A filter to use when listing toolchains.")
    var toolchainSelector: String?

    internal mutating func run() throws {
        let selector = try self.toolchainSelector.map { input in
            try ToolchainSelector(parsing: input)
        }

        let toolchains = currentPlatform.listToolchains(selector: selector)
        let activeToolchain = try currentPlatform.currentToolchain()

        let printToolchain = { (toolchain: ToolchainVersion) in
            var message = "\(toolchain)"
            if toolchain == activeToolchain {
                message += " (in use)"
            }
            print(message)
        }

        if let selector {
            let modifier: String
            switch selector {
            case let .stable(major, minor, nil):
                modifier = "\(major).\(minor) release"
            case .snapshot(.main, nil):
                modifier = "main development snapshot"
            case let .snapshot(.release(major, minor), nil):
                modifier = "\(major).\(minor) development snapshot"
            default:
                modifier = "matching"
            }

            let message = "installed \(modifier) toolchains"
            print(message)
            print(String(repeating: "-", count: message.utf8.count))
            for toolchain in toolchains {
                printToolchain(toolchain)
            }
        } else {
            print("installed release toolchains")
            print("----------------------------")
            for toolchain in toolchains where toolchain.isStableRelease() {
                printToolchain(toolchain)
            }

            print("")
            print("installed snapshot toolchains")
            print("-----------------------------")
            for toolchain in toolchains where toolchain.isSnapshot() {
                printToolchain(toolchain)
            }
        }
    }
}
