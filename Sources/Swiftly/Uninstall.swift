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

        print("The following toolchains will be uninstalled:")

        for toolchain in toolchains {
            print("  \(toolchain)")
        }

        print("Proceed? (y/n)", terminator: ": ")
        let proceed = readLine(strippingNewline: true) ?? "n"

        guard proceed == "y" else {
            print("aborting uninstall")
            return
        }

        print()

        for toolchain in toolchains {
            print("Uninstalling \(toolchain)...", terminator: "")
            try currentPlatform.uninstall(version: toolchain)
            print("done")
        }

        print()
        print("\(toolchains.count) toolchain(s) successfully uninstalled")
    }
}
