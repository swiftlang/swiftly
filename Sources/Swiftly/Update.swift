import ArgumentParser
import SwiftlyCore

struct Update: SwiftlyCommand {
    public static var configuration = CommandConfiguration(
        abstract: "Update an installed toolchain to a newer version."
    )

    @Argument(help: ArgumentHelp(
        "The installed toolchain to update.",
        discussion: """

        Updating a toolchain involves uninstalling it and installing a new toolchain that is \
        newer than it.

        The string "latest" can be provided to update the installed stable release toolchain \
        with the newest version to the latest available stable release. This may update the \
        toolchain to later major, minor, or patch versions.

            $ swiftly update latest

        A specific stable release can be updated to the latest patch version for that release by \
        specifying the entire version:

            $ swiftly update 5.6.0

        Omitting the patch in the specified version will update the latest installed toolchain for \
        the provided minor version to the latest available release for that minor version. For \
        example, the following will update the latest installed Swift 5.4 release toolchain to \
        the latest available Swift 5.4 release:

            $ swiftly update 5.4

        The latest snapshot toolchain for a given development branch can be updated to \
        the latest available snapshot for that branch by specifying just the branch:

            $ swiflty update 5.7-snapshot
            $ swiftly update main-snapshot
        """
    ))
    var toolchain: String?

    @Flag(
        name: [.long, .customShort("y")],
        help: "Update the selected toolchains without prompting for confirmation."
    )
    var assumeYes: Bool = false

    public mutating func run() async throws {
        var config = try Config.load()

        guard let oldToolchain = try self.oldToolchain(config) else {
            if let toolchain = self.toolchain {
                SwiftlyCore.print("No installed toolchain matched \"\(toolchain)\"")
            } else {
                SwiftlyCore.print("No toolchains are currently installed")
            }
            return
        }

        guard let newToolchain = try await self.fetchNewToolchain(old: oldToolchain) else {
            SwiftlyCore.print("\(oldToolchain) is already up to date")
            return
        }

        guard !config.installedToolchains.contains(newToolchain) else {
            SwiftlyCore.print("The newest version of \(oldToolchain) (\(newToolchain)) is already installed")
            return
        }

        if !self.assumeYes {
            SwiftlyCore.print("Update \(oldToolchain) ⟶ \(newToolchain)?")
            guard SwiftlyCore.promptForConfirmation(defaultBehavior: true) else {
                SwiftlyCore.print("Aborting")
                return
            }
        }

        try await Install.execute(version: newToolchain, &config)

        if config.inUse == oldToolchain {
            try await Use.execute(newToolchain, &config)
        }

        try await Uninstall.execute(oldToolchain, &config)
        SwiftlyCore.print("Successfully updated \(oldToolchain) ⟶ \(newToolchain)")
    }

    private func oldToolchain(_ config: Config) throws -> ToolchainVersion? {
        guard let input = self.toolchain else {
            return config.inUse
        }

        let selector = try ToolchainSelector(parsing: input)
        let toolchains = config.listInstalledToolchains(selector: selector)

        // When multiple toolchains are matched, update the latest one.
        // This is for situations such as `swiftly update 5.5` when both
        // 5.5.1 and 5.5.2 are installed (5.5.2 will be updated).
        return toolchains.max()
    }

    private func fetchNewToolchain(old: ToolchainVersion) async throws -> ToolchainVersion? {
        switch old {
        case let .stable(oldRelease):
            return try await HTTP.getReleaseToolchains(limit: 1) { release in
                release.major == oldRelease.major
                    && release.minor == oldRelease.minor
                    && release.patch > oldRelease.patch
            }.first.map(ToolchainVersion.stable)
        case let .snapshot(oldSnapshot):
            return try await HTTP.getSnapshotToolchains(limit: 1) { snapshot in
                snapshot.branch == oldSnapshot.branch && snapshot.date > oldSnapshot.date
            }.first.map(ToolchainVersion.snapshot)
        }
    }
}
