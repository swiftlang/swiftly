import ArgumentParser
import SwiftlyCore

struct Uninstall: ParsableCommand {
    @Argument(help: "The toolchain to uninstall.")
    var version: String

    mutating func run() throws {
        let selector = try ToolchainSelector(parsing: self.version)
        let toolchains = currentPlatform.listToolchains(selector: selector)

        guard !toolchains.isEmpty else {
            print("no toolchains matched \"\(self.version)\"")
            return
        }

        print("Uninstall the following toolchains?")

        for toolchain in toolchains {
            print("    \(toolchain)")
        }

        print("Y/n")

        for toolchain in toolchains {
            print("Uninstalling \(toolchain)...")
            try currentPlatform.uninstall(version: toolchain)
            print("done!")
        }
    }
}
