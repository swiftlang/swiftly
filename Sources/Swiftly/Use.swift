import ArgumentParser
import SwiftlyCore

struct Use: ParsableCommand {
    @Argument(help: "The toolchain to use.")
    var toolchain: String

    internal mutating func run() throws {
        let selector = try ToolchainSelector(parsing: self.toolchain)
        guard let toolchain = currentPlatform.listToolchains(selector: selector).max() else {
            print("no installed toolchains match \"\(self.toolchain)\"")
            return
        }

        let old = try currentPlatform.currentToolchain()
        try currentPlatform.use(toolchain)

        var message = "The current toolchain is now \(toolchain)"
        if let old {
            message += " (was \(old))"
        }

        print(message)
    }
}
