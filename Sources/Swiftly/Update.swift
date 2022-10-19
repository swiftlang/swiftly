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

    public mutating func run() async throws {
        guard let oldToolchain = try self.oldToolchain() else {
            if let toolchain = self.toolchain {
                print("No installed toolchain matched \"\(toolchain)\"")
            } else {
                print("No toolchains are currently installed")
            }
            return
        }

        guard let newToolchain = try await self.newToolchain(old: oldToolchain) else {
            print("\(oldToolchain) is already up to date!")
            return
        }

        print("updating \(oldToolchain) -> \(newToolchain)")
        try await Install.execute(version: newToolchain)
        try Swiftly.currentPlatform.uninstall(version: oldToolchain)
        print("successfully updated \(oldToolchain) -> \(newToolchain)")
    }

    private func oldToolchain() throws -> ToolchainVersion? {
        guard let input = self.toolchain else {
            return try Config.load().inUse
        }

        let selector = try ToolchainSelector(parsing: input)
        let toolchains = try Config.load().listInstalledToolchains(selector: selector)

        // When multiple toolchains are matched, update the latest one.
        // This is for situations such as `swiftly update 5.5` when both
        // 5.5.1 and 5.5.2 are installed (5.5.2 will be updated).
        return toolchains.max()
    }

    private func newToolchain(old: ToolchainVersion) async throws -> ToolchainVersion? {
        switch old {
        case let .stable(oldRelease):
            return try await HTTP.getReleaseToolchains(limit: 1) { release in
                release.major == oldRelease.major
                    && release.minor == oldRelease.minor
                    && release.patch > oldRelease.patch
            }.first.map(ToolchainVersion.stable)
        default:
            // TODO: fetch newer snapshots
            return nil
        }
    }
}
