import ArgumentParser
import SwiftlyCore

struct Use: ParsableCommand {
    public static var configuration = CommandConfiguration(
        abstract: "Set the active toolchain."
    )

    @Argument(help: ArgumentHelp(
        "The toolchain to use.",
        discussion: """

        The string "latest" can be provided to use the most recent stable version release:

            $ swiftly use latest

        A specific toolchain can be selected by providing a full toolchain name, for example \
        a stable release version with patch (e.g. a.b.c):

            $ swiftly use 5.4.2

        Or a snapshot with date:

            $ swiftly use 5.7-snapshot-2022-06-20
            $ swiftly use main-snapshot-2022-06-20

        The latest patch release of a specific minor version can be used by omitting the \
        patch version:

            $ swiftly use 5.6

        Likewise, the latest snapshot associated with a given development branch can be \
        used by omitting the date:

            $ swiftly install 5.7-snapshot
            $ swiftly install main-snapshot
        """
    ))
    var toolchain: String

    internal mutating func run() throws {
        let selector = try ToolchainSelector(parsing: self.toolchain)
        guard let toolchain = Swiftly.currentPlatform.listToolchains(selector: selector).max() else {
            print("no installed toolchains match \"\(self.toolchain)\"")
            return
        }

        let old = try Swiftly.currentPlatform.currentToolchain()

        try Swiftly.currentPlatform.use(toolchain)
        try Config.update { config in
            config.inUse = toolchain
        }

        var message = "The current toolchain is now \(toolchain)"
        if let old {
            message += " (was \(old))"
        }

        print(message)
    }
}
