import ArgumentParser
import SwiftlyCore

internal struct Use: SwiftlyCommand {
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

    internal mutating func run() async throws {
        let selector = try ToolchainSelector(parsing: self.toolchain)
        var config = try Config.load()

        guard let toolchain = config.listInstalledToolchains(selector: selector).max() else {
            print("No installed toolchains match \"\(self.toolchain)\"")
            return
        }

        try await Self.execute(toolchain)
    }

    internal static func execute(_ toolchain: ToolchainVersion) async throws {
        var config = try Config.load()
        let previousToolchain = config.inUse

        guard toolchain != previousToolchain else {
            print("\(toolchain) is already in use")
            return
        }

        try Swiftly.currentPlatform.use(toolchain)
        config.inUse = toolchain
        try config.save()

        var message = "Set the active toolchain to \(toolchain)"
        if let previousToolchain {
            message += " (was \(previousToolchain))"
        }

        print(message)
    }
}
