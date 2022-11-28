import ArgumentParser
import SwiftlyCore

struct Uninstall: SwiftlyCommand {
    public static var configuration = CommandConfiguration(
        abstract: "Remove an installed toolchain."
    )

    @Argument(help: ArgumentHelp(
        "The toolchain(s) to uninstall.",
        discussion: """

        The toolchain selector provided determines which toolchains to uninstall. Specific \
        toolchains can be uninstalled by using their full names as the selector, for example \
        a full stable release version with patch (a.b.c): 

            $ swiftly uninstall 5.2.1

        Or a full snapshot name with date (a.b-snapshot-YYYY-mm-dd):

            $ swiftly uninstall 5.7-snapshot-2022-06-20

        Less specific selectors can be used to uninstall multiple toolchains at once. For instance, \
        the patch version can be omitted to uninstall all toolchains associated with a given minor version release:

            $ swiftly uninstall 5.6

        Similarly, all snapshot toolchains associated with a given branch can be uninstalled by omitting the date:

            $ swiftly uninstall main-snapshot
            $ swiftly uninstall 5.7-snapshot
        """
    ))
    var toolchain: String

    mutating func run() async throws {
        let selector = try ToolchainSelector(parsing: self.toolchain)
        let config = try Config.load()
        let toolchains = config.listInstalledToolchains(selector: selector)

        guard !toolchains.isEmpty else {
            SwiftlyCore.print("No toolchains matched \"\(self.toolchain)\"")
            return
        }

        SwiftlyCore.print("The following toolchains will be uninstalled:")

        for toolchain in toolchains {
            SwiftlyCore.print("  \(toolchain)")
        }

        let proceed = SwiftlyCore.readLine(prompt: "Proceed? (y/n)") ?? "n"

        guard proceed == "y" else {
            SwiftlyCore.print("Aborting uninstall")
            return
        }

        SwiftlyCore.print()

        for toolchain in toolchains {
            SwiftlyCore.print("Uninstalling \(toolchain)...", terminator: "")
            try Swiftly.currentPlatform.uninstall(toolchain)
            try Config.update { config in
                config.installedToolchains.remove(toolchain)
            }
            SwiftlyCore.print("done")
        }

        SwiftlyCore.print()
        SwiftlyCore.print("\(toolchains.count) toolchain(s) successfully uninstalled")

        var latestConfig = try Config.load()

        // If the in-use toolchain was one of the uninstalled toolchains, use the latest installed
        // toolchain.
        if let previouslyInUse = latestConfig.inUse, toolchains.contains(previouslyInUse) {
            if let toUse = latestConfig.listInstalledToolchains(selector: .latest).max() ?? latestConfig.installedToolchains.max() {
                try await Use.execute(toUse)
            } else {
                // If there are no more toolchains installed, clear the inUse config entry.
                latestConfig.inUse = nil
                try latestConfig.save()
            }
        }
    }
}
