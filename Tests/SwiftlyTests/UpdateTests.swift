import Foundation
@testable import Swiftly
@testable import SwiftlyCore
import XCTest

final class UpdateTests: SwiftlyTests {
    private let httpClient = HTTP(toolchainDownloader: MockToolchainDownloader())

    /// Verifies that updating the currently in-use toolchain can be updated, and that after update the new toolchain
    /// will be in-use instead.
    func testUpdateInUse() async throws {
        try await self.withTestHome {
            try await self.installMockedToolchain(selector: "5.0.0")

            var update = try self.parseCommand(Update.self, ["update", "-y"])
            update.httpClient = self.httpClient
            try await update.run()

            let config = try Config.load()
            let inUse = config.inUse!.asStableRelease!
            XCTAssertGreaterThan(inUse, .init(major: 5, minor: 0, patch: 0))
            XCTAssertEqual(inUse.major, 5)
            XCTAssertEqual(inUse.minor, 0)
            XCTAssertGreaterThan(inUse.patch, 0)

            try await self.validateInstalledToolchains(
                [config.inUse!],
                description: "update should update the in use toolchain to latest patch"
            )

            try await self.validateInUse(expected: config.inUse!)
        }
    }

    func testUpdateSnapshot() async throws {
        let branches: [ToolchainVersion.Snapshot.Branch] = [
            .main,
            .release(major: 5, minor: 9)
        ]

        for branch in branches {
            try await self.withTestHome {
                let date = "2023-09-19"
                try await self.installMockedToolchain(selector: .snapshot(branch: branch, date: date))

                var update = try self.parseCommand(Update.self, ["update", "-y", "\(branch.name)-snapshot"])
                update.httpClient = self.httpClient
                try await update.run()

                let config = try Config.load()
                let inUse = config.inUse!.asSnapshot!
                XCTAssertGreaterThan(inUse, .init(branch: branch, date: date))
                XCTAssertEqual(inUse.branch, branch)
                XCTAssertGreaterThan(inUse.date, date)

                try await self.validateInstalledToolchains(
                    [config.inUse!],
                    description: "update should work with snapshots"
                )
            }
        }
    }

    /// Verify that the latest of all the matching release toolchains is updated.
    func testUpdateSelectsLatestMatchingStableRelease() async throws {
        try await self.withTestHome {
            try await self.installMockedToolchain(selector: "5.0.1")
            try await self.installMockedToolchain(selector: "5.0.0")

            var update = try self.parseCommand(Update.self, ["update", "-y", "5.0"])
            update.httpClient = self.httpClient
            try await update.run()

            let config = try Config.load()
            let inUse = config.inUse!.asStableRelease!
            XCTAssertEqual(inUse.major, 5)
            XCTAssertEqual(inUse.minor, 0)
            XCTAssertGreaterThan(inUse.patch, 1)

            try await self.validateInstalledToolchains(
                [config.inUse!, .init(major: 5, minor: 0, patch: 0)],
                description: "update with ambiguous selector should update the latest matching toolchain"
            )
        }
    }

    /// Verify that the latest of all the matching snapshot toolchains is updated.
    func testUpdateSelectsLatestMatchingSnapshotRelease() async throws {
        let branches: [ToolchainVersion.Snapshot.Branch] = [
            .main,
            .release(major: 5, minor: 9)
        ]

        for branch in branches {
            try await self.withTestHome {
                try await self.installMockedToolchain(selector: .snapshot(branch: branch, date: "2023-09-19"))
                try await self.installMockedToolchain(selector: .snapshot(branch: branch, date: "2023-09-16"))

                var update = try self.parseCommand(Update.self, ["update", "-y", "\(branch.name)-snapshot"])
                update.httpClient = self.httpClient
                try await update.run()

                let config = try Config.load()
                let inUse = config.inUse!.asSnapshot!

                XCTAssertEqual(inUse.branch, branch)
                XCTAssertGreaterThan(inUse.date, "2023-09-16")

                try await self.validateInstalledToolchains(
                    [config.inUse!, .init(snapshotBranch: branch, date: "2023-09-16")],
                    description: "update with ambiguous selector should update the latest matching toolchain"
                )
            }
        }
    }
}
