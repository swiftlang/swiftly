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

    public var httpClient = SwiftlyHTTPClient()

    private enum CodingKeys: String, CodingKey {
        case toolchain, assumeYes
    }

    public mutating func run() async throws {
        var config = try Config.load()

        guard let parameters = try self.resolveUpdateParameters(config) else {
            if let toolchain = self.toolchain {
                SwiftlyCore.print("No installed toolchain matched \"\(toolchain)\"")
            } else {
                SwiftlyCore.print("No toolchains are currently installed")
            }
            return
        }

        guard let newToolchain = try await self.fetchNewToolchain(parameters) else {
            SwiftlyCore.print("\(parameters.oldToolchain) is already up to date")
            return
        }

        guard !config.installedToolchains.contains(newToolchain) else {
            SwiftlyCore.print("The newest version of \(parameters.oldToolchain) (\(newToolchain)) is already installed")
            return
        }

        if !self.assumeYes {
            SwiftlyCore.print("Update \(parameters.oldToolchain) ⟶ \(newToolchain)?")
            guard SwiftlyCore.promptForConfirmation(defaultBehavior: true) else {
                SwiftlyCore.print("Aborting")
                return
            }
        }

        try await Install.execute(version: newToolchain, &config, self.httpClient)

        if config.inUse == parameters.oldToolchain {
            try await Use.execute(newToolchain, &config)
        }

        try await Uninstall.execute(parameters.oldToolchain, &config)
        SwiftlyCore.print("Successfully updated \(parameters.oldToolchain) ⟶ \(newToolchain)")
    }

    private func resolveUpdateParameters(_ config: Config) throws -> UpdateParameters? {
        let selector = try self.toolchain.map { try ToolchainSelector(parsing: $0) }

        let oldToolchain: ToolchainVersion?
        if let selector {
            let toolchains = config.listInstalledToolchains(selector: selector)
            // When multiple toolchains are matched, update the latest one.
            // This is for situations such as `swiftly update 5.5` when both
            // 5.5.1 and 5.5.2 are installed (5.5.2 will be updated).
            oldToolchain = toolchains.max()
        } else {
            oldToolchain = config.inUse
        }

        guard let oldToolchain else {
            return nil
        }

        switch oldToolchain {
        case let .snapshot(snapshot):
            return .snapshot(old: snapshot)
        case let .stable(stable):
            switch selector {
            case .none:
                return .stable(old: stable, target: .latestPatch)
            case let .stable(_, minor, _):
                if minor == nil {
                    return .stable(old: stable, target: .latestMinor)
                } else {
                    return .stable(old: stable, target: .latestPatch)
                }
            case .latest:
                return .stable(old: stable, target: .latest)
            default:
                fatalError("unreachable")
            }
        }
    }

    private func fetchNewToolchain(_ bounds: UpdateParameters) async throws -> ToolchainVersion? {
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
                snapshot.branch == old.branch && snapshot.date > old.date
            }.first.map(ToolchainVersion.snapshot)
        }
    }
}

enum UpdateParameters {
    enum StableUpdateTarget {
        case latest
        case latestMinor
        case latestPatch
    }

    case stable(old: ToolchainVersion.StableRelease, target: StableUpdateTarget)
    case snapshot(old: ToolchainVersion.Snapshot)

    var oldToolchain: ToolchainVersion {
        switch self {
        case let .stable(old, _):
            return .stable(old)
        case let .snapshot(old):
            return .snapshot(old)
        }
    }
}
