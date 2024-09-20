import Foundation
@testable import Swiftly
@testable import SwiftlyCore
import XCTest

final class UseTests: SwiftlyTests {
    static let homeName = "useTests"

    /// Execute a `use` command with the provided argument. Then validate that the configuration is updated properly and
    /// the in-use swift executable prints the the provided expectedVersion.
    func useAndValidate(argument: String, expectedVersion: ToolchainVersion) async throws {
        var use = try self.parseCommand(Use.self, ["use", "-g", argument])
        try await use.run()

        XCTAssertEqual(try Config.load().inUse, expectedVersion)
    }

    /// Tests that the `use` command can switch between installed stable release toolchains.
    func testUseStable() async throws {
        try await self.withMockedHome(homeName: Self.homeName, toolchains: Self.allToolchains) {
            try await self.useAndValidate(argument: Self.oldStable.name, expectedVersion: Self.oldStable)
            try await self.useAndValidate(argument: Self.newStable.name, expectedVersion: Self.newStable)
            try await self.useAndValidate(argument: Self.newStable.name, expectedVersion: Self.newStable)
        }
    }

    /// Tests that that "latest" can be provided to the `use` command to select the installed stable release
    /// toolchain with the most recent version.
    func testUseLatestStable() async throws {
        try await self.withMockedHome(homeName: Self.homeName, toolchains: Self.allToolchains) {
            // Use an older toolchain.
            try await self.useAndValidate(argument: Self.oldStable.name, expectedVersion: Self.oldStable)

            // Use latest, assert that it switched to the latest installed stable release.
            try await self.useAndValidate(argument: "latest", expectedVersion: Self.newStable)

            // Try to use latest again, assert no error was thrown and no changes were made.
            try await self.useAndValidate(argument: "latest", expectedVersion: Self.newStable)

            // Explicitly specify the current latest toolchain, assert no errors and no changes were made.
            try await self.useAndValidate(argument: Self.newStable.name, expectedVersion: Self.newStable)

            // Switch back to the old toolchain, verify it works.
            try await self.useAndValidate(argument: Self.oldStable.name, expectedVersion: Self.oldStable)
        }
    }

    /// Tests that the latest installed patch release toolchain for a given major/minor version pair can be selected by
    /// omitting the patch version (e.g. `use 5.6`).
    func testUseLatestStablePatch() async throws {
        try await self.withMockedHome(homeName: Self.homeName, toolchains: Self.allToolchains) {
            try await self.useAndValidate(argument: Self.oldStable.name, expectedVersion: Self.oldStable)

            let oldStableVersion = Self.oldStable.asStableRelease!

            // Drop the patch version and assert that the latest patch of the provided major.minor was chosen.
            try await self.useAndValidate(
                argument: "\(oldStableVersion.major).\(oldStableVersion.minor)",
                expectedVersion: Self.oldStableNewPatch
            )

            // Assert that selecting it again doesn't change anything.
            try await self.useAndValidate(
                argument: "\(oldStableVersion.major).\(oldStableVersion.minor)",
                expectedVersion: Self.oldStableNewPatch
            )

            // Switch back to an older patch, try selecting a newer version that isn't installed, and assert
            // that nothing changed.
            try await self.useAndValidate(argument: Self.oldStable.name, expectedVersion: Self.oldStable)
            let latestPatch = Self.oldStableNewPatch.asStableRelease!.patch
            try await self.useAndValidate(
                argument: "\(oldStableVersion.major).\(oldStableVersion.minor).\(latestPatch + 1)",
                expectedVersion: Self.oldStable
            )
        }
    }

    /// Tests that the `use` command can switch between installed main snapshot toolchains.
    func testUseMainSnapshot() async throws {
        try await self.withMockedHome(homeName: Self.homeName, toolchains: Self.allToolchains) {
            // Switch to a non-snapshot.
            try await self.useAndValidate(argument: Self.newStable.name, expectedVersion: Self.newStable)
            try await self.useAndValidate(argument: Self.oldMainSnapshot.name, expectedVersion: Self.oldMainSnapshot)
            try await self.useAndValidate(argument: Self.newMainSnapshot.name, expectedVersion: Self.newMainSnapshot)
            // Verify that using the same snapshot again doesn't throw an error.
            try await self.useAndValidate(argument: Self.newMainSnapshot.name, expectedVersion: Self.newMainSnapshot)
            try await self.useAndValidate(argument: Self.oldMainSnapshot.name, expectedVersion: Self.oldMainSnapshot)
        }
    }

    /// Tests that the latest installed main snapshot toolchain can be selected by omitting the
    /// date (e.g. `use main-snapshot`).
    func testUseLatestMainSnapshot() async throws {
        try await self.withMockedHome(homeName: Self.homeName, toolchains: Self.allToolchains) {
            // Switch to a non-snapshot.
            try await self.useAndValidate(argument: Self.newStable.name, expectedVersion: Self.newStable)
            // Switch to the latest main snapshot.
            try await self.useAndValidate(argument: "main-snapshot", expectedVersion: Self.newMainSnapshot)
            // Switch to it again, assert no errors or changes were made.
            try await self.useAndValidate(argument: "main-snapshot", expectedVersion: Self.newMainSnapshot)
            // Switch to it again, this time by name. Assert no errors or changes were made.
            try await self.useAndValidate(argument: Self.newMainSnapshot.name, expectedVersion: Self.newMainSnapshot)
            // Switch to an older snapshot, verify it works.
            try await self.useAndValidate(argument: Self.oldMainSnapshot.name, expectedVersion: Self.oldMainSnapshot)
        }
    }

    /// Tests that the `use` command can switch between installed release snapshot toolchains.
    func testUseReleaseSnapshot() async throws {
        try await self.withMockedHome(homeName: Self.homeName, toolchains: Self.allToolchains) {
            // Switch to a non-snapshot.
            try await self.useAndValidate(argument: Self.newStable.name, expectedVersion: Self.newStable)
            try await self.useAndValidate(
                argument: Self.oldReleaseSnapshot.name,
                expectedVersion: Self.oldReleaseSnapshot
            )
            try await self.useAndValidate(
                argument: Self.newReleaseSnapshot.name,
                expectedVersion: Self.newReleaseSnapshot
            )
            // Verify that using the same snapshot again doesn't throw an error.
            try await self.useAndValidate(
                argument: Self.newReleaseSnapshot.name,
                expectedVersion: Self.newReleaseSnapshot
            )
            try await self.useAndValidate(
                argument: Self.oldReleaseSnapshot.name,
                expectedVersion: Self.oldReleaseSnapshot
            )
        }
    }

    /// Tests that the latest installed release snapshot toolchain can be selected by omitting the
    /// date (e.g. `use 5.7-snapshot`).
    func testUseLatestReleaseSnapshot() async throws {
        try await self.withMockedHome(homeName: Self.homeName, toolchains: Self.allToolchains) {
            // Switch to a non-snapshot.
            try await self.useAndValidate(argument: Self.newStable.name, expectedVersion: Self.newStable)
            // Switch to the latest snapshot for the given release.
            guard case let .release(major, minor) = Self.newReleaseSnapshot.asSnapshot!.branch else {
                fatalError("expected release in snapshot release version")
            }
            try await self.useAndValidate(
                argument: "\(major).\(minor)-snapshot",
                expectedVersion: Self.newReleaseSnapshot
            )
            // Switch to it again, assert no errors or changes were made.
            try await self.useAndValidate(
                argument: "\(major).\(minor)-snapshot",
                expectedVersion: Self.newReleaseSnapshot
            )
            // Switch to it again, this time by name. Assert no errors or changes were made.
            try await self.useAndValidate(
                argument: Self.newReleaseSnapshot.name,
                expectedVersion: Self.newReleaseSnapshot
            )
            // Switch to an older snapshot, verify it works.
            try await self.useAndValidate(
                argument: Self.oldReleaseSnapshot.name,
                expectedVersion: Self.oldReleaseSnapshot
            )
        }
    }

    /// Tests that the `use` command gracefully exits when executed before any toolchains have been installed.
    func testUseNoInstalledToolchains() async throws {
        try await self.withMockedHome(homeName: Self.homeName, toolchains: []) {
            var use = try self.parseCommand(Use.self, ["use", "-g", "latest"])
            try await use.run()

            var config = try Config.load()
            XCTAssertEqual(config.inUse, nil)

            use = try self.parseCommand(Use.self, ["use", "-g", "5.6.0"])
            try await use.run()

            config = try Config.load()
            XCTAssertEqual(config.inUse, nil)
        }
    }

    /// Tests that the `use` command gracefully handles being executed with toolchain names that haven't been installed.
    func testUseNonExistent() async throws {
        try await self.withMockedHome(homeName: Self.homeName, toolchains: Self.allToolchains) {
            // Switch to a valid toolchain.
            try await self.useAndValidate(argument: Self.oldStable.name, expectedVersion: Self.oldStable)

            // Try various non-existent toolchains.
            try await self.useAndValidate(argument: "1.2.3", expectedVersion: Self.oldStable)
            try await self.useAndValidate(argument: "5.7-snapshot-1996-01-01", expectedVersion: Self.oldStable)
            try await self.useAndValidate(argument: "6.7-snapshot", expectedVersion: Self.oldStable)
            try await self.useAndValidate(argument: "main-snapshot-1996-01-01", expectedVersion: Self.oldStable)
        }
    }

    /// Tests that the `use` command works with all the installed toolchains in this test harness.
    func testUseAll() async throws {
        try await self.withMockedHome(homeName: Self.homeName, toolchains: Self.allToolchains) {
            let config = try Config.load()

            for toolchain in config.installedToolchains {
                try await self.useAndValidate(
                    argument: toolchain.name,
                    expectedVersion: toolchain
                )
            }
        }
    }

    /// Tests that running a use command without an argument prints the currently in-use toolchain.
    func testPrintInUse() async throws {
        let toolchains = [
            Self.newStable,
            Self.newMainSnapshot,
            Self.newReleaseSnapshot,
        ]
        try await self.withMockedHome(homeName: Self.homeName, toolchains: Set(toolchains)) {
            for toolchain in toolchains {
                var use = try self.parseCommand(Use.self, ["use", "-g", toolchain.name])
                try await use.run()

                var useEmpty = try self.parseCommand(Use.self, ["use", "-g"])
                var output = try await useEmpty.runWithMockedIO()

                XCTAssert(output.contains(where: { $0.contains(String(describing: toolchain)) }))

                useEmpty = try self.parseCommand(Use.self, ["use", "-g", "--print-location"])
                output = try await useEmpty.runWithMockedIO()

                XCTAssert(output.contains(where: { $0.contains(Swiftly.currentPlatform.findToolchainLocation(toolchain).path) }))
            }
        }
    }

    /// Tests in-use toolchain selected by the .swift-version file.
    func testSwiftVersionFile() async throws {
        let toolchains = [
            Self.newStable,
            Self.newMainSnapshot,
            Self.newReleaseSnapshot,
        ]
        try await self.withMockedHome(homeName: Self.homeName, toolchains: Set(toolchains)) {
            let versionFile = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".swift-version")

            // GIVEN: a directory with a swift version file that selects a particular toolchain
            try Self.newStable.name.write(to: versionFile, atomically: true, encoding: .utf8)
            // WHEN: checking which toolchain is selected with the use command
            var useCmd = try self.parseCommand(Use.self, ["use"])
            var output = try await useCmd.runWithMockedIO()
            // THEN: the output shows this toolchain is in use with this working directory
            XCTAssert(output.contains(where: { $0.contains(Self.newStable.name) }))

            // GIVEN: a directory with a swift version file that selects a particular toolchain
            // WHEN: using another toolchain version
            useCmd = try self.parseCommand(Use.self, ["use", Self.newMainSnapshot.name])
            output = try await useCmd.runWithMockedIO()
            // THEN: the swift version file is updated to this toolchain version
            var versionFileContents = try String(contentsOf: versionFile, encoding: .utf8)
            XCTAssertEqual(Self.newMainSnapshot.name, versionFileContents)
            // THEN: the use command reports this toolchain to be in use
            XCTAssert(output.contains(where: { $0.contains(Self.newMainSnapshot.name) }))

            // GIVEN: a directory with no swift version file at the top of a git repository
            try FileManager.default.removeItem(atPath: versionFile.path)
            let gitDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".git")
            try FileManager.default.createDirectory(atPath: gitDir.path, withIntermediateDirectories: false)
            // WHEN: using a toolchain version
            useCmd = try self.parseCommand(Use.self, ["use", Self.newReleaseSnapshot.name])
            try await useCmd.run()
            // THEN: a swift version file is created
            XCTAssert(FileManager.default.fileExists(atPath: versionFile.path))
            // THEN: the version file contains the specified version
            versionFileContents = try String(contentsOf: versionFile, encoding: .utf8)
            XCTAssertEqual(Self.newReleaseSnapshot.name, versionFileContents)

            // GIVEN: a directory with a swift version file at the top of a git repository
            try "1.2.3".write(to: versionFile, atomically: true, encoding: .utf8)
            // WHEN: using with a toolchain selector that can select more than one version, but matches one of the installed toolchains
            let broadSelector = ToolchainSelector.stable(major: Self.newStable.asStableRelease!.major, minor: nil, patch: nil)
            useCmd = try self.parseCommand(Use.self, ["use", broadSelector.description])
            try await useCmd.run()
            // THEN: the swift version file is set to the specific toolchain version that was installed including major, minor, and patch
            versionFileContents = try String(contentsOf: versionFile, encoding: .utf8)
            XCTAssertEqual(Self.newStable.name, versionFileContents)
        }
    }
}
