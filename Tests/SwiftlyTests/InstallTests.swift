@testable import Swiftly
@testable import SwiftlyCore
import Foundation
import XCTest

final class InstallTests: SwiftlyTests {
    func testInstallLatest() async throws {
        try await self.withTestHome {
            var cmd = try self.parseCommand(Install.self, ["install", "latest"])
            try await cmd.run()

            let config = try Config.load()

            XCTAssertTrue(!config.installedToolchains.isEmpty)

            let installedToolchain = config.installedToolchains.first!

            guard case let .stable(release) = installedToolchain else {
                XCTFail("expected swiftly install latest to insall release toolchain but got \(installedToolchain)")
                return
            }

            // As of writing this, 5.7.0 is the latest stable release. Assert it is at least that new.
            XCTAssertTrue(release >= ToolchainVersion.StableRelease(major: 5, minor: 7, patch: 0))

            try await validateInstalledToolchains([installedToolchain], description: "install latest")
        }
    }

    func testInstallLatestPatchVersion() async throws {
        try await self.withTestHome {
            var cmd = try self.parseCommand(Install.self, ["install", "5.6"])
            try await cmd.run()

            let config = try Config.load()

            XCTAssertTrue(!config.installedToolchains.isEmpty)

            let installedToolchain = config.installedToolchains.first!

            guard case let .stable(release) = installedToolchain else {
                XCTFail("expected swiftly install latest to insall release toolchain but got \(installedToolchain)")
                return
            }

            // As of writing this, 5.6.3 is the latest 5.6 patch release. Assert it is at least that new.
            XCTAssertTrue(release >= ToolchainVersion.StableRelease(major: 5, minor: 6, patch: 3))

            try await validateInstalledToolchains([installedToolchain], description: "install latest")
        }
    }

    func testInstallReleases() async throws {
        try await self.withTestHome {
            var installedToolchains: Set<ToolchainVersion> = []

            var cmd = try self.parseCommand(Install.self, ["install", "5.7.0"])
            try await cmd.run()

            installedToolchains.insert(ToolchainVersion(major: 5, minor: 7, patch: 0))
            try await validateInstalledToolchains(
                installedToolchains,
                description: "install a stable release toolchain"
            )

            cmd = try self.parseCommand(Install.self, ["install", "5.6.1"])
            try await cmd.run()

            installedToolchains.insert(ToolchainVersion(major: 5, minor: 6, patch: 1))
            try await validateInstalledToolchains(
                installedToolchains,
                description: "install another stable release toolchain"
            )
        }
    }

    func testInstallSnapshots() async throws {
        try await self.withTestHome {
            var installedToolchains: Set<ToolchainVersion> = []

            var cmd = try self.parseCommand(Install.self, ["install", "main-snapshot-2022-09-10"])
            try await cmd.run()

            installedToolchains.insert(ToolchainVersion(snapshotBranch: .main, date: "2022-09-10"))
            try await validateInstalledToolchains(
                installedToolchains,
                description: "install a main snapshot toolchain"
            )

            cmd = try self.parseCommand(Install.self, ["install", "5.7-snapshot-2022-08-30"])
            try await cmd.run()

            installedToolchains.insert(ToolchainVersion(snapshotBranch: .release(major: 5, minor: 7), date: "2022-08-30"))
            try await validateInstalledToolchains(
                installedToolchains,
                description: "install a 5.7 snapshot toolchain"
            )
        }
    }

    func testInstallLatestMainSnapshot() async throws {
        try await self.withTestHome {
            var cmd = try self.parseCommand(Install.self, ["install", "main-snapshot"])
            try await cmd.run()

            let config = try Config.load()

            XCTAssertTrue(!config.installedToolchains.isEmpty)

            let installedToolchain = config.installedToolchains.first!

            guard case let .snapshot(snapshot) = installedToolchain, snapshot.branch == .main else {
                XCTFail("expected swiftly install main-snapshot to install snapshot toolchain but got \(installedToolchain)")
                return
            }

            // As of writing this, 2022-09-12 is the date of the latest main snapshot. Assert it is at least that new.
            XCTAssertTrue(snapshot.date >= "2022-09-12")

            try await validateInstalledToolchains(
                [installedToolchain],
                description: "install the latest main snapshot toolchain"
            )
        }
    }

    func testInstallLatestReleaseSnapshot() async throws {
        try await self.withTestHome {
            var cmd = try self.parseCommand(Install.self, ["install", "5.7-snapshot"])
            try await cmd.run()

            let config = try Config.load()

            XCTAssertTrue(!config.installedToolchains.isEmpty)

            let installedToolchain = config.installedToolchains.first!

            guard case let .snapshot(snapshot) = installedToolchain, snapshot.branch == .release(major: 5, minor: 7) else {
                XCTFail("expected swiftly install 5.7-snapshot to install snapshot toolchain but got \(installedToolchain)")
                return
            }

            // As of writing this, 2022-08-30 is the date of the latest 5.7 snapshot. Assert it is at least that new.
            XCTAssertTrue(snapshot.date >= "2022-08-30")

            try await validateInstalledToolchains(
                [installedToolchain],
                description: "install the latest 5.7 snapshot toolchain"
            )
        }
    }

    func testInstallReleaseAndSnapshots() async throws {
        try await self.withTestHome {
            var cmd = try self.parseCommand(Install.self, ["install", "main-snapshot-2022-09-10"])
            try await cmd.run()

            cmd = try self.parseCommand(Install.self, ["install", "5.7-snapshot-2022-08-30"])
            try await cmd.run()

            cmd = try self.parseCommand(Install.self, ["install", "5.7.0"])
            try await cmd.run()

            try await validateInstalledToolchains(
                [
                    ToolchainVersion(snapshotBranch: .main, date: "2022-09-10"),
                    ToolchainVersion(snapshotBranch: .release(major: 5, minor: 7), date: "2022-08-30"),
                    ToolchainVersion(major: 5, minor: 7, patch: 0)
                ],
                description: "install both snapshots and releases"
            )
        }
    }

    func duplicateTest(_ version: String) async throws {
        try await self.withTestHome {
            var cmd = try self.parseCommand(Install.self, ["install", version])
            try await cmd.run()

            let before = try Config.load()

            let startTime = Date()
            cmd = try try self.parseCommand(Install.self, ["install", version])
            try await cmd.run()

            // Assert that swiftly didn't attempt to download a new toolchain.
            XCTAssertTrue(startTime.timeIntervalSinceNow.magnitude < 5)

            let after = try Config.load()
            XCTAssertEqual(before, after)
        }
    }

    func testInstallDuplicateReleases() async throws {
        try await duplicateTest("5.7.0")
        try await duplicateTest("latest")
    }

    func testInstallDuplicateMainSnapshots() async throws {
        try await duplicateTest("main-snapshot-2022-09-10")
        try await duplicateTest("main-snapshot")
    }

    func testInstallDuplicateReleaseSnapshots() async throws {
        try await duplicateTest("5.7-snapshot-2022-08-30")
        try await duplicateTest("5.7-snapshot")
    }
}
