import ArgumentParser
import Foundation
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

        If no argument is provided to the update command, the currently in-use toolchain will \
        be updated. If that toolchain is a stable release, it will be updated to the latest \
        patch version for that major.minor version. If the currently in-use toolchain is a \
        snapshot, then it will be updated to the latest snapshot for that development branch.

            $ swiftly update

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

        Similarly, omitting the minor in the specified version will update the latest installed \
        toolchain for the provided major version to the latest available release for that major \
        version. Note that this may update the toolchain to a later minor version.

            $ swiftly update 5

        The latest snapshot toolchain for a given development branch can be updated to \
        the latest available snapshot for that branch by specifying just the branch:

            $ swiftly update 5.7-snapshot
            $ swiftly update main-snapshot

        A specific snapshot toolchain can be updated by including the date:

            $ swiftly update 5.9-snapshot-2023-09-20
            $ swiftly update main-snapshot-2023-09-20
        """
    ))
    var toolchain: String?

    @OptionGroup var root: GlobalOptions

    @Flag(inversion: .prefixedNo, help: "Verify the toolchain's PGP signature before proceeding with installation.")
    var verify = true

    @Option(help: ArgumentHelp(
        "A file path to a location for a post installation script",
        discussion: """
        If the toolchain that is installed has extra post installation steps they they will be
        written to this file as commands that can be run after the installation.
        """
    ))
    var postInstallFile: String?

    private enum CodingKeys: String, CodingKey {
        case toolchain, root, verify, postInstallFile
    }

    public mutating func run() async throws {
        try validateSwiftly()
        var config = try Config.load()

        guard let parameters = try await self.resolveUpdateParameters(&config) else {
            if let toolchain = self.toolchain {
                SwiftlyCore.print("No installed toolchain matched \"\(toolchain)\"")
            } else {
                SwiftlyCore.print("No toolchains are currently installed")
            }
            return
        }

        guard let newToolchain = try await self.lookupNewToolchain(config, parameters) else {
            SwiftlyCore.print("\(parameters.oldToolchain) is already up to date")
            return
        }

        guard !config.installedToolchains.contains(newToolchain) else {
            SwiftlyCore.print("The newest version of \(parameters.oldToolchain) (\(newToolchain)) is already installed")
            return
        }

        if !self.root.assumeYes {
            SwiftlyCore.print("Update \(parameters.oldToolchain) -> \(newToolchain)?")
            guard SwiftlyCore.promptForConfirmation(defaultBehavior: true) else {
                SwiftlyCore.print("Aborting")
                return
            }
        }

        let (postInstallScript, pathChanged) = try await Install.execute(
            version: newToolchain,
            &config,
            useInstalledToolchain: config.inUse == parameters.oldToolchain,
            verifySignature: self.verify,
            verbose: self.root.verbose,
            assumeYes: self.root.assumeYes
        )

        try await Uninstall.execute(parameters.oldToolchain, &config, verbose: self.root.verbose)
        SwiftlyCore.print("Successfully updated \(parameters.oldToolchain) ⟶ \(newToolchain)")

        if let postInstallScript {
            guard let postInstallFile = self.postInstallFile else {
                throw SwiftlyError(message: """

                There are some system dependencies that should be installed before using this toolchain.
                You can run the following script as the system administrator (e.g. root) to prepare
                your system:

                \(postInstallScript)
                """)
            }

            try Data(postInstallScript.utf8).write(to: URL(fileURLWithPath: postInstallFile), options: .atomic)
        }

        if pathChanged {
            SwiftlyCore.print("""
            NOTE: Swiftly has updated some elements in your path and your shell may not yet be
            aware of the changes. You can run 'hash -r' to update your shell.

            """)
        }
    }

    /// Using the provided toolchain selector and the current config, returns a set of parameters that determines
    /// what new toolchains the selected toolchain can be updated to.
    ///
    /// If the selector does not match an installed toolchain, this returns nil.
    /// If no selector is provided, the currently in-use toolchain will be used as the basis for the returned
    /// parameters.
    private func resolveUpdateParameters(_ config: inout Config) async throws -> UpdateParameters? {
        let selector = try self.toolchain.map { try ToolchainSelector(parsing: $0) }

        let oldToolchain: ToolchainVersion?
        if let selector {
            let toolchains = config.listInstalledToolchains(selector: selector)
            // When multiple toolchains are matched, update the latest one.
            // This is for situations such as `swiftly update 5.5` when both
            // 5.5.1 and 5.5.2 are installed (5.5.2 will be updated).
            oldToolchain = toolchains.max()
        } else {
            (oldToolchain, _) = try await selectToolchain(config: &config)
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

    /// Tries to find a toolchain version that meets the provided parameters, if one exists.
    /// This does not download the toolchain, but it does query the swift.org API to find the suitable toolchain.
    private func lookupNewToolchain(_ config: Config, _ bounds: UpdateParameters) async throws -> ToolchainVersion? {
        switch bounds {
        case let .stable(old, range):
            return try await SwiftlyCore.httpClient.getReleaseToolchains(platform: config.platform, limit: 1) { release in
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
            let newerSnapshotToolchains: [ToolchainVersion.Snapshot]
            do {
                newerSnapshotToolchains = try await SwiftlyCore.httpClient.getSnapshotToolchains(platform: config.platform, branch: old.branch, limit: 1) { snapshot in
                    snapshot.branch == old.branch && snapshot.date > old.date
                }
            } catch let branchNotFoundErr as SwiftlyHTTPClient.SnapshotBranchNotFoundError {
                throw SwiftlyError(message: "Snapshot branch \(branchNotFoundErr.branch) cannot be updated. One possible reason for this is that there has been a new release published to swift.org and this snapshot is for an older release. Snapshots are only available for the newest release and the main branch. You can install a fresh snapshot toolchain from the either the latest release x.y (major.minor) with `swiftly install x.y-snapshot` or from the main branch with `swiftly install main-snapshot`.")
            } catch {
                throw error
            }

            return newerSnapshotToolchains.first.map(ToolchainVersion.snapshot)
        }
    }
}

/// Enum that models an update operation.
///
/// For snapshots, includes the old version of the snapshot that will be updated to the latest snapshot on the same
/// branch.
enum UpdateParameters {
    /// Bounds of an update to a stable release toolchain.
    enum StableUpdateTarget {
        /// No bounds on the update. The old toolchain will be replaced with the latest available stable release of any
        /// major version.
        case latest

        /// The old toolchain will be replaced with the latest available stable release with the same major version.
        case latestMinor

        /// The old toolchain will be replaced with the latest available stable release with the same major and minor
        /// versions.
        case latestPatch
    }

    /// Stable release update operation.
    ///
    /// "old" refers to the toolchain version being updated, and "target" specifies a range of acceptable versions to
    /// update to relative to "old".
    ///
    /// For example, .stable(old: "5.0.0", target: .latestMinor) models an update operation that will replace the
    /// installed 5.0.0 release toolchain to the latest 5.x.y release.
    case stable(old: ToolchainVersion.StableRelease, target: StableUpdateTarget)

    /// Snapshot toolchain update operation.
    ///
    /// "old" refers to the snapshot toolchain that will be updated. It will be replaced with the latest available
    /// snapshot toolchain with the same branch as "old", if one exists.
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
