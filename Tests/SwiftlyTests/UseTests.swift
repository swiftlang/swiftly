@testable import Swiftly
@testable import SwiftlyCore
import Foundation
import XCTest

final class UseTests: SwiftlyTests {
    static let homeName = "useTests"

    // Below are some constants indicating which versions are installed during setup.

    static let oldStable = ToolchainVersion(major: 5, minor: 6, patch: 0)
    static let oldStableNewPatch = ToolchainVersion(major: 5, minor: 6, patch: 3)
    static let newStable = ToolchainVersion(major: 5, minor: 7, patch: 0)
    static let oldMainSnapshot = ToolchainVersion(snapshotBranch: .main, date: "2022-09-10")
    static let newMainSnapshot = ToolchainVersion(snapshotBranch: .main, date: "2022-10-22")
    static let oldReleaseSnapshot = ToolchainVersion(snapshotBranch: .release(major: 5, minor: 7), date: "2022-08-27")
    static let newReleaseSnapshot = ToolchainVersion(snapshotBranch: .release(major: 5, minor: 7), date: "2022-08-30")

    /// Construct a mock home directory with the toolchains listed above installed and run the provided closure within
    /// the context of that home.
    func runUseTest(f: () async throws -> Void) async throws {
        try await self.withTestHome(name: Self.homeName, createNew: true, cleanUp: true) {
            // List of toolchains to be installed. Snapshot toolchains have a git hash included to facilitate
            // implementing the --version output.
            let allToolchains: [(ToolchainVersion, String?)] = [
                (Self.oldStable, nil),
                (Self.oldStableNewPatch, nil),
                (Self.newStable, nil),
                (Self.oldMainSnapshot, "005c9f34031"),
                (Self.newMainSnapshot, "4c546d3d07c"),
                (Self.oldReleaseSnapshot, "4c347d27c92"),
                (Self.newReleaseSnapshot, "1e80674d67f")
            ]

            for (toolchain, hash) in allToolchains {
                let toolchainDir = Config.swiftlyToolchainsDir.appendingPathComponent(toolchain.name)
                try FileManager.default.createDirectory(at: toolchainDir, withIntermediateDirectories: true)

                let toolchainBinDir = toolchainDir
                    .appendingPathComponent("usr", isDirectory: true)
                    .appendingPathComponent("bin", isDirectory: true)
                try FileManager.default.createDirectory(
                    at: toolchainBinDir,
                    withIntermediateDirectories: true
                )

                // create dummy executable file that just prints the toolchain's version
                let executablePath = toolchainBinDir.appendingPathComponent("swift")
                try executablePath.deleteIfExists()

                let script = """
                    #!/usr/bin/env bash

                    echo '\(toolchain.name)'
                    """

                let data = script.data(using: .utf8)!
                try data.write(to: executablePath)

                // make the file executable
                try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executablePath.path)
            }

            try Config.update { config in
                config.installedToolchains = Set(allToolchains.map({ $0.0 }))
            }

            var use = try self.parseCommand(Use.self, ["use", "latest"])
            try await use.run()

            try await f()
        }
    }

    func useAndValidate(argument: String, expectedVersion: ToolchainVersion) async throws {
        var use = try self.parseCommand(Use.self, ["use", argument])
        try await use.run()

        let swiftExecutableURL = Config.swiftlyBinDir.appendingPathComponent("swift")
        let process = Process()
        process.executableURL = swiftExecutableURL

        let outputPipe = Pipe()
        process.standardOutput = outputPipe

        try process.run()
        process.waitUntilExit()

        guard let outputData = try outputPipe.fileHandleForReading.readToEnd() else {
            throw SwiftlyTestError(message: "got no output from swift binary at path \(swiftExecutableURL.path)")
        }

        let toolchainVersion = String(decoding: outputData, as: UTF8.self).trimmingCharacters(in: .newlines)
        XCTAssertEqual(toolchainVersion, expectedVersion.name)
    }

    func testUseStable() async throws {
        try await self.runUseTest {
            try await self.useAndValidate(argument: Self.oldStable.name, expectedVersion: Self.oldStable)
            try await self.useAndValidate(argument: Self.newStable.name, expectedVersion: Self.newStable)
            try await self.useAndValidate(argument: Self.newStable.name, expectedVersion: Self.newStable)
        }
    }

    func testUseLatestStable() async throws {
        try await self.runUseTest {
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

    func testUseLatestStablePatch() async throws {
        try await self.runUseTest {
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

    func testUseMainSnapshot() async throws {
        try await self.runUseTest {
            // Switch to a non-snapshot.
            try await self.useAndValidate(argument: Self.newStable.name, expectedVersion: Self.newStable)
            try await self.useAndValidate(argument: Self.oldMainSnapshot.name, expectedVersion: Self.oldMainSnapshot)
            try await self.useAndValidate(argument: Self.newMainSnapshot.name, expectedVersion: Self.newMainSnapshot)
            // Verify that using the same snapshot again doesn't throw an error.
            try await self.useAndValidate(argument: Self.newMainSnapshot.name, expectedVersion: Self.newMainSnapshot)
            try await self.useAndValidate(argument: Self.oldMainSnapshot.name, expectedVersion: Self.oldMainSnapshot)
        }
    }

    func testUseLatestMainSnapshot() async throws {
        try await self.runUseTest {
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

    func testUseReleaseSnapshot() async throws {
        try await self.runUseTest {
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

    func testUseLatestReleaseSnapshot() async throws {
        try await self.runUseTest {
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

    func testUseNoInstalledToolchains() async throws {
        try await self.withTestHome {
            var use = try self.parseCommand(Use.self, ["use", "latest"])
            try await use.run()

            var config = try Config.load()
            XCTAssertEqual(config.inUse, nil)

            use = try self.parseCommand(Use.self, ["use", "5.6.0"])
            try await use.run()

            config = try Config.load()
            XCTAssertEqual(config.inUse, nil)
        }
    }

    func testUseNonExistent() async throws {
        try await self.runUseTest {
            // Switch to a valid toolchain.
            try await self.useAndValidate(argument: Self.oldStable.name, expectedVersion: Self.oldStable)

            // Try various non-existent toolchains.
            try await self.useAndValidate(argument: "1.2.3", expectedVersion: Self.oldStable)
            try await self.useAndValidate(argument: "5.7-snapshot-1996-01-01", expectedVersion: Self.oldStable)
            try await self.useAndValidate(argument: "6.7-snapshot", expectedVersion: Self.oldStable)
            try await self.useAndValidate(argument: "main-snapshot-1996-01-01", expectedVersion: Self.oldStable)
        }
    }

    func testUseAll() async throws {
        try await self.runUseTest {
            let config = try Config.load()

            for toolchain in config.installedToolchains {
                try await self.useAndValidate(
                    argument: toolchain.name,
                    expectedVersion: toolchain
                )
            }
        }
    }

    func testSymlinks() async throws {
        try await self.runUseTest {
            let config = try Config.load()

            for toolchain in config.installedToolchains {
                var use = try self.parseCommand(Use.self, ["use", toolchain.name])
                try await use.run()

                let files = try FileManager.default.contentsOfDirectory(atPath: Config.swiftlyBinDir.path).sorted()
                XCTAssertEqual(files, Config.symlinkedExecutables.sorted())
            }
        }
    }

    func testFoo() async throws {
        try await self.runUseTest { print("ok") }
    }
}
