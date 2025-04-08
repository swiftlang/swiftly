import Foundation
@testable import Swiftly
@testable import SwiftlyCore
import Testing

@Suite struct UseTests {
    static let homeName = "useTests"

    /// Execute a `use` command with the provided argument. Then validate that the configuration is updated properly and
    /// the in-use swift executable prints the the provided expectedVersion.
    func useAndValidate(argument: String, expectedVersion: ToolchainVersion) async throws {
        try await SwiftlyTests.runCommand(Use.self, ["use", "-g", argument])

        #expect(try Config.load().inUse == expectedVersion)
    }

    /// Tests that the `use` command can switch between installed stable release toolchains.
    @Test(.mockHomeToolchains()) func useStable() async throws {
        try await self.useAndValidate(argument: ToolchainVersion.oldStable.name, expectedVersion: .oldStable)
        try await self.useAndValidate(argument: ToolchainVersion.newStable.name, expectedVersion: .newStable)
        try await self.useAndValidate(argument: ToolchainVersion.newStable.name, expectedVersion: .newStable)
    }

    /// Tests that that "latest" can be provided to the `use` command to select the installed stable release
    /// toolchain with the most recent version.
    @Test(.mockHomeToolchains()) func useLatestStable() async throws {
        // Use an older toolchain.
        try await self.useAndValidate(argument: ToolchainVersion.oldStable.name, expectedVersion: .oldStable)

        // Use latest, assert that it switched to the latest installed stable release.
        try await self.useAndValidate(argument: "latest", expectedVersion: .newStable)

        // Try to use latest again, assert no error was thrown and no changes were made.
        try await self.useAndValidate(argument: "latest", expectedVersion: .newStable)

        // Explicitly specify the current latest toolchain, assert no errors and no changes were made.
        try await self.useAndValidate(argument: ToolchainVersion.newStable.name, expectedVersion: .newStable)

        // Switch back to the old toolchain, verify it works.
        try await self.useAndValidate(argument: ToolchainVersion.oldStable.name, expectedVersion: .oldStable)
    }

    /// Tests that the latest installed patch release toolchain for a given major/minor version pair can be selected by
    /// omitting the patch version (e.g. `use 5.6`).
    @Test(.mockHomeToolchains()) func useLatestStablePatch() async throws {
        try await self.useAndValidate(argument: ToolchainVersion.oldStable.name, expectedVersion: .oldStable)

        let oldStableVersion = ToolchainVersion.oldStable.asStableRelease!

        // Drop the patch version and assert that the latest patch of the provided major.minor was chosen.
        try await self.useAndValidate(
            argument: "\(oldStableVersion.major).\(oldStableVersion.minor)",
            expectedVersion: .oldStableNewPatch
        )

        // Assert that selecting it again doesn't change anything.
        try await self.useAndValidate(
            argument: "\(oldStableVersion.major).\(oldStableVersion.minor)",
            expectedVersion: .oldStableNewPatch
        )

        // Switch back to an older patch, try selecting a newer version that isn't installed, and assert
        // that nothing changed.
        try await self.useAndValidate(argument: ToolchainVersion.oldStable.name, expectedVersion: .oldStable)
        let latestPatch = ToolchainVersion.oldStableNewPatch.asStableRelease!.patch
        try await self.useAndValidate(
            argument: "\(oldStableVersion.major).\(oldStableVersion.minor).\(latestPatch + 1)",
            expectedVersion: .oldStable
        )
    }

    /// Tests that the `use` command can switch between installed main snapshot toolchains.
    @Test(.mockHomeToolchains()) func useMainSnapshot() async throws {
        // Switch to a non-snapshot.
        try await self.useAndValidate(argument: ToolchainVersion.newStable.name, expectedVersion: .newStable)
        try await self.useAndValidate(argument: ToolchainVersion.oldMainSnapshot.name, expectedVersion: .oldMainSnapshot)
        try await self.useAndValidate(argument: ToolchainVersion.newMainSnapshot.name, expectedVersion: .newMainSnapshot)
        // Verify that using the same snapshot again doesn't throw an error.
        try await self.useAndValidate(argument: ToolchainVersion.newMainSnapshot.name, expectedVersion: .newMainSnapshot)
        try await self.useAndValidate(argument: ToolchainVersion.oldMainSnapshot.name, expectedVersion: .oldMainSnapshot)
    }

    /// Tests that the latest installed main snapshot toolchain can be selected by omitting the
    /// date (e.g. `use main-snapshot`).
    @Test(.mockHomeToolchains()) func useLatestMainSnapshot() async throws {
        // Switch to a non-snapshot.
        try await self.useAndValidate(argument: ToolchainVersion.newStable.name, expectedVersion: .newStable)
        // Switch to the latest main snapshot.
        try await self.useAndValidate(argument: "main-snapshot", expectedVersion: .newMainSnapshot)
        // Switch to it again, assert no errors or changes were made.
        try await self.useAndValidate(argument: "main-snapshot", expectedVersion: .newMainSnapshot)
        // Switch to it again, this time by name. Assert no errors or changes were made.
        try await self.useAndValidate(argument: ToolchainVersion.newMainSnapshot.name, expectedVersion: .newMainSnapshot)
        // Switch to an older snapshot, verify it works.
        try await self.useAndValidate(argument: ToolchainVersion.oldMainSnapshot.name, expectedVersion: .oldMainSnapshot)
    }

    /// Tests that the `use` command can switch between installed release snapshot toolchains.
    @Test(.mockHomeToolchains()) func useReleaseSnapshot() async throws {
        // Switch to a non-snapshot.
        try await self.useAndValidate(argument: ToolchainVersion.newStable.name, expectedVersion: .newStable)
        try await self.useAndValidate(
            argument: ToolchainVersion.oldReleaseSnapshot.name,
            expectedVersion: .oldReleaseSnapshot
        )
        try await self.useAndValidate(
            argument: ToolchainVersion.newReleaseSnapshot.name,
            expectedVersion: .newReleaseSnapshot
        )
        // Verify that using the same snapshot again doesn't throw an error.
        try await self.useAndValidate(
            argument: ToolchainVersion.newReleaseSnapshot.name,
            expectedVersion: .newReleaseSnapshot
        )
        try await self.useAndValidate(
            argument: ToolchainVersion.oldReleaseSnapshot.name,
            expectedVersion: .oldReleaseSnapshot
        )
    }

    /// Tests that the latest installed release snapshot toolchain can be selected by omitting the
    /// date (e.g. `use 5.7-snapshot`).
    @Test(.mockHomeToolchains()) func useLatestReleaseSnapshot() async throws {
        // Switch to a non-snapshot.
        try await self.useAndValidate(argument: ToolchainVersion.newStable.name, expectedVersion: .newStable)
        // Switch to the latest snapshot for the given release.
        guard case let .release(major, minor) = ToolchainVersion.newReleaseSnapshot.asSnapshot!.branch else {
            fatalError("expected release in snapshot release version")
        }
        try await self.useAndValidate(
            argument: "\(major).\(minor)-snapshot",
            expectedVersion: .newReleaseSnapshot
        )
        // Switch to it again, assert no errors or changes were made.
        try await self.useAndValidate(
            argument: "\(major).\(minor)-snapshot",
            expectedVersion: .newReleaseSnapshot
        )
        // Switch to it again, this time by name. Assert no errors or changes were made.
        try await self.useAndValidate(
            argument: ToolchainVersion.newReleaseSnapshot.name,
            expectedVersion: .newReleaseSnapshot
        )
        // Switch to an older snapshot, verify it works.
        try await self.useAndValidate(
            argument: ToolchainVersion.oldReleaseSnapshot.name,
            expectedVersion: .oldReleaseSnapshot
        )
    }

    /// Tests that the `use` command gracefully exits when executed before any toolchains have been installed.
    @Test(.mockHomeToolchains(toolchains: [])) func useNoInstalledToolchains() async throws {
        try await SwiftlyTests.runCommand(Use.self, ["use", "-g", "latest"])

        var config = try Config.load()
        #expect(config.inUse == nil)

        try await SwiftlyTests.runCommand(Use.self, ["use", "-g", "5.6.0"])

        config = try Config.load()
        #expect(config.inUse == nil)
    }

    /// Tests that the `use` command gracefully handles being executed with toolchain names that haven't been installed.
    @Test(.mockHomeToolchains()) func useNonExistent() async throws {
        // Switch to a valid toolchain.
        try await self.useAndValidate(argument: ToolchainVersion.oldStable.name, expectedVersion: .oldStable)

        // Try various non-existent toolchains.
        try await self.useAndValidate(argument: "1.2.3", expectedVersion: .oldStable)
        try await self.useAndValidate(argument: "5.7-snapshot-1996-01-01", expectedVersion: .oldStable)
        try await self.useAndValidate(argument: "6.7-snapshot", expectedVersion: .oldStable)
        try await self.useAndValidate(argument: "main-snapshot-1996-01-01", expectedVersion: .oldStable)
    }

    /// Tests that the `use` command works with all the installed toolchains in this test harness.
    @Test(.mockHomeToolchains()) func useAll() async throws {
        let config = try Config.load()

        for toolchain in config.installedToolchains {
            try await self.useAndValidate(
                argument: toolchain.name,
                expectedVersion: toolchain
            )
        }
    }

    /// Tests that running a use command without an argument prints the currently in-use toolchain.
    @Test func printInUse() async throws {
        let toolchains = [
            ToolchainVersion.newStable,
            .newMainSnapshot,
            .newReleaseSnapshot,
        ]
        try await SwiftlyTests.withMockedHome(homeName: Self.homeName, toolchains: Set(toolchains)) {
            for toolchain in toolchains {
                try await SwiftlyTests.runCommand(Use.self, ["use", "-g", toolchain.name])

                var output = try await SwiftlyTests.runWithMockedIO(Use.self, ["use", "-g"])

                #expect(output.contains(where: { $0.contains(String(describing: toolchain)) }))

                output = try await SwiftlyTests.runWithMockedIO(Use.self, ["use", "-g", "--print-location"])

                #expect(output.contains(where: { $0.contains(Swiftly.currentPlatform.findToolchainLocation(SwiftlyTests.ctx, toolchain).path) }))
            }
        }
    }

    /// Tests in-use toolchain selected by the .swift-version file.
    @Test func swiftVersionFile() async throws {
        let toolchains = [
            ToolchainVersion.newStable,
            .newMainSnapshot,
            .newReleaseSnapshot,
        ]
        try await SwiftlyTests.withMockedHome(homeName: Self.homeName, toolchains: Set(toolchains)) {
            let versionFile = SwiftlyTests.ctx.currentDirectory.appendingPathComponent(".swift-version")

            // GIVEN: a directory with a swift version file that selects a particular toolchain
            try ToolchainVersion.newStable.name.write(to: versionFile, atomically: true, encoding: .utf8)
            // WHEN: checking which toolchain is selected with the use command
            var output = try await SwiftlyTests.runWithMockedIO(Use.self, ["use"])
            // THEN: the output shows this toolchain is in use with this working directory
            #expect(output.contains(where: { $0.contains(ToolchainVersion.newStable.name) }))

            // GIVEN: a directory with a swift version file that selects a particular toolchain
            // WHEN: using another toolchain version
            output = try await SwiftlyTests.runWithMockedIO(Use.self, ["use", ToolchainVersion.newMainSnapshot.name])
            // THEN: the swift version file is updated to this toolchain version
            var versionFileContents = try String(contentsOf: versionFile, encoding: .utf8)
            #expect(ToolchainVersion.newMainSnapshot.name == versionFileContents)
            // THEN: the use command reports this toolchain to be in use
            #expect(output.contains(where: { $0.contains(ToolchainVersion.newMainSnapshot.name) }))

            // GIVEN: a directory with no swift version file at the top of a git repository
            try FileManager.default.removeItem(atPath: versionFile.path)
            let gitDir = SwiftlyTests.ctx.currentDirectory.appendingPathComponent(".git")
            try FileManager.default.createDirectory(atPath: gitDir.path, withIntermediateDirectories: false)
            // WHEN: using a toolchain version
            try await SwiftlyTests.runCommand(Use.self, ["use", ToolchainVersion.newReleaseSnapshot.name])
            // THEN: a swift version file is created
            #expect(FileManager.default.fileExists(atPath: versionFile.path))
            // THEN: the version file contains the specified version
            versionFileContents = try String(contentsOf: versionFile, encoding: .utf8)
            #expect(ToolchainVersion.newReleaseSnapshot.name == versionFileContents)

            // GIVEN: a directory with a swift version file at the top of a git repository
            try "1.2.3".write(to: versionFile, atomically: true, encoding: .utf8)
            // WHEN: using with a toolchain selector that can select more than one version, but matches one of the installed toolchains
            let broadSelector = ToolchainSelector.stable(major: ToolchainVersion.newStable.asStableRelease!.major, minor: nil, patch: nil)
            try await SwiftlyTests.runCommand(Use.self, ["use", broadSelector.description])
            // THEN: the swift version file is set to the specific toolchain version that was installed including major, minor, and patch
            versionFileContents = try String(contentsOf: versionFile, encoding: .utf8)
            #expect(ToolchainVersion.newStable.name == versionFileContents)
        }
    }
}
