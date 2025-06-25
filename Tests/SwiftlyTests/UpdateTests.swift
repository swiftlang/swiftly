import Foundation
@testable import Swiftly
@testable import SwiftlyCore
import Testing

@Suite struct UpdateTests {
    /// Verify updating the most up-to-date toolchain has no effect.
    @Test(.testHomeMockedToolchain()) func updateLatest() async throws {
        try await SwiftlyTests.installMockedToolchain(selector: .latest)

        let beforeUpdateConfig = try await Config.load()

        try await SwiftlyTests.runCommand(Update.self, ["update", "latest", "--no-verify", "--post-install-file=\(fs.mktemp())"])

        #expect(try await Config.load() == beforeUpdateConfig)
        try await SwiftlyTests.validateInstalledToolchains(
            beforeUpdateConfig.installedToolchains,
            description: "Updating latest toolchain should have no effect"
        )
    }

    /// Verify that attempting to update when no toolchains are installed has no effect.
    @Test(.testHomeMockedToolchain()) func updateLatestWithNoToolchains() async throws {
        try await SwiftlyTests.runCommand(Update.self, ["update", "latest", "--no-verify", "--post-install-file=\(fs.mktemp())"])

        try await SwiftlyTests.validateInstalledToolchains(
            [],
            description: "Updating should not install any toolchains"
        )
    }

    /// Verify that updating the latest installed toolchain updates it to the latest available toolchain.
    @Test(.testHomeMockedToolchain()) func updateLatestToLatest() async throws {
        try await SwiftlyTests.installMockedToolchain(selector: .stable(major: 5, minor: 9, patch: 0))
        try await SwiftlyTests.runCommand(Update.self, ["update", "-y", "latest", "--no-verify", "--post-install-file=\(fs.mktemp())"])

        let config = try await Config.load()
        let inUse = config.inUse!.asStableRelease!

        #expect(inUse > .init(major: 5, minor: 9, patch: 0))
        try await SwiftlyTests.validateInstalledToolchains(
            [config.inUse!],
            description: "Updating toolchain should properly install new toolchain and uninstall old"
        )
    }

    /// Verify that the latest installed toolchain for a given major version can be updated to the latest
    /// released minor version.
    @Test(.testHomeMockedToolchain()) func updateToLatestMinor() async throws {
        try await SwiftlyTests.installMockedToolchain(selector: .stable(major: 5, minor: 9, patch: 0))
        try await SwiftlyTests.runCommand(Update.self, ["update", "-y", "5", "--no-verify", "--post-install-file=\(fs.mktemp())"])

        let config = try await Config.load()
        let inUse = config.inUse!.asStableRelease!

        #expect(inUse.major == 5)
        #expect(inUse.minor > 0)

        try await SwiftlyTests.validateInstalledToolchains(
            [config.inUse!],
            description: "Updating toolchain should properly install new toolchain and uninstall old"
        )
    }

    /// Verify that a toolchain can be updated to the latest patch version of that toolchain's minor version.
    @Test(.testHomeMockedToolchain()) func updateToLatestPatch() async throws {
        try await SwiftlyTests.installMockedToolchain(selector: "5.9.0")

        try await SwiftlyTests.runCommand(Update.self, ["update", "-y", "5.9.0", "--no-verify", "--post-install-file=\(fs.mktemp())"])

        let config = try await Config.load()
        let inUse = config.inUse!.asStableRelease!

        #expect(inUse.major == 5)
        #expect(inUse.minor == 9)
        #expect(inUse.patch > 0)

        try await SwiftlyTests.validateInstalledToolchains(
            [config.inUse!],
            description: "Updating toolchain should properly install new toolchain and uninstall old"
        )
    }

    /// Verifies that updating the currently global default toolchain can be updated, and that after update the new toolchain
    /// will be the global default instead.
    @Test(.testHomeMockedToolchain()) func updateGlobalDefault() async throws {
        try await SwiftlyTests.installMockedToolchain(selector: "6.0.0")

        try await SwiftlyTests.runCommand(Update.self, ["update", "-y", "--no-verify", "--post-install-file=\(fs.mktemp())"])

        let config = try await Config.load()
        let inUse = config.inUse!.asStableRelease!
        #expect(inUse > .init(major: 6, minor: 0, patch: 0))
        #expect(inUse.major == 6)
        #expect(inUse.minor == 0)
        #expect(inUse.patch > 0)

        try await SwiftlyTests.validateInstalledToolchains(
            [config.inUse!],
            description: "update should update the in use toolchain to latest patch"
        )

        try await SwiftlyTests.validateInUse(expected: config.inUse!)
    }

    /// Verifies that updating the currently in-use toolchain can be updated, and that after update the new toolchain
    /// will be in-use with the swift version file updated.
    @Test(.testHomeMockedToolchain()) func updateInUse() async throws {
        try await SwiftlyTests.installMockedToolchain(selector: "6.0.0")

        let versionFile = SwiftlyTests.ctx.currentDirectory / ".swift-version"
        try "6.0.0".write(to: versionFile, atomically: true)

        try await SwiftlyTests.runCommand(Update.self, ["update", "-y", "--no-verify", "--post-install-file=\(fs.mktemp())"])

        let versionFileContents = try String(contentsOf: versionFile)
        let inUse = try ToolchainVersion(parsing: versionFileContents)
        #expect(inUse > .init(major: 6, minor: 0, patch: 0))

        // Since the global default was set to 6.0.0, and that toolchain is no longer installed
        // the update should have unset it to prevent the config from going into a bad state.
        let config = try await Config.load()
        #expect(config.inUse == nil)

        // The new toolchain should be installed
        #expect(config.installedToolchains.contains(inUse))
    }

    /// Verifies that snapshots, both from the main branch and from development branches, can be updated.
    @Test(
        .testHomeMockedToolchain(),
        arguments: [
            ToolchainVersion.Snapshot.Branch.main,
            .release(major: 6, minor: 0),
        ]
    ) func updateSnapshot(_ branch: ToolchainVersion.Snapshot.Branch) async throws {
        let date = branch == .main ? ToolchainVersion.oldMainSnapshot.asSnapshot!.date : ToolchainVersion.oldReleaseSnapshot.asSnapshot!.date
        try await SwiftlyTests.installMockedToolchain(selector: .snapshot(branch: branch, date: date))

        try await SwiftlyTests.runCommand(
            Update.self, ["update", "-y", "\(branch.name)-snapshot", "--no-verify", "--post-install-file=\(fs.mktemp())"]
        )

        let config = try await Config.load()
        let inUse = config.inUse!.asSnapshot!
        #expect(inUse > .init(branch: branch, date: date))
        #expect(inUse.branch == branch)
        #expect(inUse.date > date)

        try await SwiftlyTests.validateInstalledToolchains(
            [config.inUse!],
            description: "update should work with snapshots"
        )
    }

    /// Verify that the latest of all the matching release toolchains is updated.
    @Test(.testHomeMockedToolchain()) func updateSelectsLatestMatchingStableRelease() async throws {
        try await SwiftlyTests.installMockedToolchain(selector: "6.0.1")
        try await SwiftlyTests.installMockedToolchain(selector: "6.0.0")

        try await SwiftlyTests.runCommand(Update.self, ["update", "-y", "6.0", "--no-verify", "--post-install-file=\(fs.mktemp())"])

        let config = try await Config.load()
        let inUse = config.inUse!.asStableRelease!
        #expect(inUse.major == 6)
        #expect(inUse.minor == 0)
        #expect(inUse.patch > 1)

        try await SwiftlyTests.validateInstalledToolchains(
            [config.inUse!, .init(major: 6, minor: 0, patch: 0)],
            description: "update with ambiguous selector should update the latest matching toolchain"
        )
    }

    /// Verify that the latest of all the matching snapshot toolchains is updated.
    @Test(
        .testHomeMockedToolchain(),
        arguments: [
            ToolchainVersion.Snapshot.Branch.main,
            .release(major: 6, minor: 0),
        ]
    ) func updateSelectsLatestMatchingSnapshotRelease(_ branch: ToolchainVersion.Snapshot.Branch) async throws {
        try await SwiftlyTests.withMockedToolchain {
            try await SwiftlyTests.installMockedToolchain(selector: .snapshot(branch: branch, date: "2024-06-19"))
            try await SwiftlyTests.installMockedToolchain(selector: .snapshot(branch: branch, date: "2024-06-18"))

            try await SwiftlyTests.runCommand(
                Update.self, ["update", "-y", "\(branch.name)-snapshot", "--no-verify", "--post-install-file=\(fs.mktemp())"]
            )

            let config = try await Config.load()
            let inUse = config.inUse!.asSnapshot!

            #expect(inUse.branch == branch)
            #expect(inUse.date > "2024-06-18")

            try await SwiftlyTests.validateInstalledToolchains(
                [config.inUse!, .init(snapshotBranch: branch, date: "2024-06-18")],
                description: "update with ambiguous selector should update the latest matching toolchain"
            )
        }
    }
}
