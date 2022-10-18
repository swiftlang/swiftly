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
        let toolchains = Swiftly.currentPlatform.listToolchains(selector: selector)

        guard !toolchains.isEmpty else {
            print("no toolchains matched \"\(self.toolchain)\"")
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
            try Swiftly.currentPlatform.uninstall(version: toolchain)
            print("done")
        }

        print()
        print("\(toolchains.count) toolchain(s) successfully uninstalled")
    }
}
