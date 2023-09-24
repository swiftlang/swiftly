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

    public var httpClient = HTTP()

	private enum CodingKeys: String, CodingKey {
		case toolchain, assumeYes
	}

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

        let bounds: UpdateBounds

        let selector = try self.toolchain.map { try ToolchainSelector(parsing: $0) }

        // TODO: de-uglify
        if let selector {
            switch oldToolchain {
            case let .snapshot(snapshot):
                bounds = .snapshot(old: snapshot)
            case let .stable(stable):
                switch selector {
                case let .stable(major, minor, patch):
                    if minor == nil {
                        bounds = .stable(old: stable, range: .latestMinor)
                    } else {
                        bounds = .stable(old: stable, range: .latestPatch)
                    }
                case .latest:
                    bounds = .stable(old: stable, range: .latest)
                default:
                    fatalError("TODO: unreachable")
                }
            }
        } else {
            switch oldToolchain {
            case let .snapshot(snapshot):
                bounds = .snapshot(old: snapshot)
            case let .stable(stable):
                bounds = .stable(old: stable, range: .latestPatch)
            }
        }

        guard let newToolchain = try await self.fetchNewToolchain(bounds: bounds) else {
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

        try await Install.execute(version: newToolchain, &config, self.httpClient)

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

    private func fetchNewToolchain(bounds: UpdateBounds) async throws -> ToolchainVersion? {
        switch bounds {
        case let .stable(old, range):
            return try await self.httpClient.getReleaseToolchains(limit: 1) { release in
                switch range {
                case .latest:
                    return release > old
                case .latestMinor:
                    return release.major == old.major && release > old
                case .latestPatch:
                    return release.major == old.major && release.minor == old.minor && release > old
                }
            }.first.map(ToolchainVersion.stable)
        case let .snapshot(old):
            return try await self.httpClient.getSnapshotToolchains(limit: 1) { snapshot in
                return snapshot.branch == old.branch && snapshot.date > old.date
            }.first.map(ToolchainVersion.snapshot)
        }
    }

    // private func fetchNewToolchain(selector: ToolchainSelector?, old: ToolchainVersion) async throws -> ToolchainVersion? {
    //     // guard let selector else {
    //     //     switch old {
    //     //     case let .stable(s):
    //     //         return try await self.httpClient.getReleaseToolchains(limit: 1) { release in
    //     //             release > old.asStableRelease!
    //     //         }
    //     //     }
    //     // }

    //     switch selector {
    //     case .latest:
    //         return try await self.httpClient.getReleaseToolchains(limit: 1) { release in
    //             release > old.asStableRelease!
    //         }
    //     case let .stable(major, minor, patch):
    //         return try await self.httpClient.getReleaseToolchains(limit: 1) { release in
    //             guard release.major == major else {
    //                 return false
    //             }

    //             if let minor {
    //                 guard minor == release.minor else {
    //                     return false
    //                 }
    //             }

    //             if let patch {
    //                 guard release.patch > patch else {
    //                     return false
    //                 }
    //             }

    //             return true
    //         }.first.map(ToolchainVersion.stable)
    //     case let .snapshot(branch, date):
    //         return try await self.httpClient.getSnapshotToolchains(limit: 1) { snapshot in
    //             guard snapshot.branch == branch else {
    //                 return false
    //             }

    //             if let date {
    //                 return snapshot.date > date
    //             }

    //             return true
    //         }.first.map(ToolchainVersion.snapshot)
    //     }
    // }
}

enum UpdateBounds {
    enum StableUpdateRange {
        case latest
        case latestMinor
        case latestPatch
    }
    case stable(old: ToolchainVersion.StableRelease, range: StableUpdateRange)
    case snapshot(old: ToolchainVersion.Snapshot)
}
