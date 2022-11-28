import Foundation
@testable import Swiftly
@testable import SwiftlyCore
import XCTest

final class UninstallTests: SwiftlyTests {
    static let homeName = "uninstallTests"

    // Below are some constants indicating which versions are installed during setup.

    static let oldStable = ToolchainVersion(major: 5, minor: 6, patch: 0)
    static let oldStableNewPatch = ToolchainVersion(major: 5, minor: 6, patch: 3)
    static let newStable = ToolchainVersion(major: 5, minor: 7, patch: 0)
    static let oldMainSnapshot = ToolchainVersion(snapshotBranch: .main, date: "2022-09-10")
    static let newMainSnapshot = ToolchainVersion(snapshotBranch: .main, date: "2022-10-22")
    static let oldReleaseSnapshot = ToolchainVersion(snapshotBranch: .release(major: 5, minor: 7), date: "2022-08-27")
    static let newReleaseSnapshot = ToolchainVersion(snapshotBranch: .release(major: 5, minor: 7), date: "2022-08-30")

    static let allToolchains: Set<ToolchainVersion> = [
        oldStable,
        oldStableNewPatch,
        newStable,
        oldMainSnapshot,
        newMainSnapshot,
        oldReleaseSnapshot,
        newReleaseSnapshot,
    ]

    func testUninstallNoInstalledToolchains() async throws {
        try await self.withMockedHome(homeName: Self.homeName, toolchains: []) {
            var uninstall = try self.parseCommand(Uninstall.self, ["uninstall", "1.2.3"])
            _ = try await uninstall.runWithOutput(input: ["y"])

            try await self.validateInstalledToolchains(
                [],
                description: "remove not-installed toolchain"
            )
        }
    }

    func testUninstallLatest() async throws {
        let toolchains = Self.allToolchains.filter({ $0.asStableRelease != nil })
        try await self.withMockedHome(homeName: Self.homeName, toolchains: toolchains) {
            var installed = toolchains

            for i in 0 ..< toolchains.count {
                var uninstall = try self.parseCommand(Uninstall.self, ["uninstall", "latest"])
                _ = try await uninstall.runWithOutput(input: ["y"])
                installed.remove(installed.max()!)

                try await self.validateInstalledToolchains(
                    installed,
                    description: "remove latest \(i)"
                )
            }

            // Ensure that uninstalling when no toolchains are installed is handled gracefully.
            var uninstall = try self.parseCommand(Uninstall.self, ["uninstall", "latest"])
            try await uninstall.run()
        }
    }

    func testUninstallStableRelease() async throws {
        try await self.withMockedHome(homeName: Self.homeName, toolchains: Self.allToolchains) {
            var installed = Self.allToolchains

            for toolchain in Self.allToolchains.filter({ $0.isStableRelease() }) {
                var uninstall = try self.parseCommand(Uninstall.self, ["uninstall", toolchain.name])
                _ = try await uninstall.runWithOutput(input: ["y"])
                installed.remove(toolchain)

                try await self.validateInstalledToolchains(
                    installed,
                    description: "remove \(toolchain)"
                )
            }

            var uninstall = try self.parseCommand(Uninstall.self, ["uninstall", "1.2.3"])
            _ = try await uninstall.runWithOutput(input: ["y"])

            try await self.validateInstalledToolchains(
                installed,
                description: "remove not-installed toolchain"
            )
        }
    }

    func testUninstallSnapshot() async throws {
        try await self.withMockedHome(homeName: Self.homeName, toolchains: Self.allToolchains) {
            var installed = Self.allToolchains

            for toolchain in Self.allToolchains.filter({ $0.isSnapshot() }) {
                var uninstall = try self.parseCommand(Uninstall.self, ["uninstall", toolchain.name])
                _ = try await uninstall.runWithOutput(input: ["y"])
                installed.remove(toolchain)

                try await self.validateInstalledToolchains(
                    installed,
                    description: "remove \(toolchain)"
                )
            }

            var uninstall = try self.parseCommand(Uninstall.self, ["uninstall", "main-snapshot-2022-01-01"])
            _ = try await uninstall.runWithOutput(input: ["y"])

            try await self.validateInstalledToolchains(
                installed,
                description: "remove not-installed toolchain"
            )
        }
    }

    func testBulkUninstall() async throws {
        let toolchains = Set(
            [
                "main-snapshot-2022-01-03",
                "main-snapshot-2022-05-02",
                "main-snapshot-2022-02-23",
                "5.8-snapshot-2022-01-03",
                "5.8-snapshot-2022-05-02",
                "5.8-snapshot-2022-02-23",
                "5.7-snapshot-2022-01-03",
                "1.1.3",
                "1.1.0",
                "1.5.54"
            ].map({ try! ToolchainVersion(parsing: $0) })
        )

        func bulkUninstallTest(
            installed: inout Set<ToolchainVersion>,
            argument: String,
            uninstalled: Set<ToolchainVersion>
        ) async throws {
            var uninstall = try self.parseCommand(Uninstall.self, ["uninstall", argument])
            let output = try await uninstall.runWithOutput(input: ["y"])
            installed.subtract(uninstalled) 
            try await self.validateInstalledToolchains(
                installed,
                description: "uninstall \(argument)"
            )
            // Ensure that swiftly checks for confirmation before uninstalling all toolchains.
            let outputToolchains = output.compactMap {
                try? ToolchainVersion(parsing: $0.trimmingCharacters(in: .whitespaces))
            }
            XCTAssertEqual(Set(outputToolchains), uninstalled)
        }

        try await self.withMockedHome(homeName: Self.homeName, toolchains: Set(toolchains)) {
            var installed = toolchains

            let mainSnapshots = installed.filter { toolchain in
                guard case .main = toolchain.asSnapshot?.branch else {
                    return false
                }
                return true
            }
            try await bulkUninstallTest(
                installed: &installed,
                argument: "main-snapshot",
                uninstalled: mainSnapshots
            )

            let releaseSnapshots = installed.filter { toolchain in
                guard case .release(major: 5, minor: 8) = toolchain.asSnapshot?.branch else {
                    return false
                }
                return true
            }
            try await bulkUninstallTest(
                installed: &installed,
                argument: "5.8-snapshot",
                uninstalled: releaseSnapshots
            )

            let releases = installed.filter { toolchain in
                guard let release = toolchain.asStableRelease else {
                    return false
                }
                return release.major == 1 && release.minor == 1
            }
            try await bulkUninstallTest(
                installed: &installed,
                argument: "1.1",
                uninstalled: releases
            )
        }
    }

    func testUninstallInUse() async throws {
        let toolchains: Set<ToolchainVersion> = [
            Self.oldStable,
            Self.newStable,
            Self.oldMainSnapshot
        ]

        try await self.withMockedHome(homeName: Self.homeName, toolchains: toolchains, inUse: Self.oldStable) {
            var installed = toolchains

            var uninstall = try self.parseCommand(Uninstall.self, ["uninstall", Self.oldStable.name])
            let output = try await uninstall.runWithOutput(input: ["y"])
            installed.remove(Self.oldStable) 
            try await self.validateInstalledToolchains(
                installed,
                description: "remove in use toolchain"
            )

            // Ensure the latest installed toolchain was used when the in-use one was uninstalled.
            try await self.validateInUse(expected: Self.newStable)

            // Ensure that something was printed indicating the latest toolchain was marked in use.
            XCTAssert(output.contains(where: { $0.contains(String(describing: Self.newStable)) }))

            uninstall = try self.parseCommand(Uninstall.self, ["uninstall", Self.newStable.name])
            let newStableOutput = try await uninstall.runWithOutput(input: ["y"])
            installed.remove(Self.newStable) 
            try await self.validateInstalledToolchains(
                installed,
                description: "remove in use toolchain"
            )

            // Ensure the latest installed toolchain was used when the in-use one was uninstalled.
            try await self.validateInUse(expected: Self.oldMainSnapshot)

            // Ensure that something was printed indicating the latest toolchain was marked in use.
            XCTAssert(newStableOutput.contains(where: { $0.contains(String(describing: Self.oldMainSnapshot)) }))

            uninstall = try self.parseCommand(Uninstall.self, ["uninstall", Self.oldMainSnapshot.name])
            _ = try await uninstall.runWithOutput(input: ["y"])
            installed.remove(Self.oldMainSnapshot) 
            try await self.validateInstalledToolchains(
                installed,
                description: "remove in use toolchain"
            )

            // Ensure the latest installed toolchain was used when the in-use one was uninstalled.
            try await self.validateInUse(expected: nil)
        }
    }

    func testUninstallAbort() async throws {
        try await self.withMockedHome(homeName: Self.homeName, toolchains: Self.allToolchains, inUse: Self.oldStable) {
            let preConfig = try Config.load()
            var uninstall = try self.parseCommand(Uninstall.self, ["uninstall", Self.oldStable.name])
            _ = try await uninstall.runWithOutput(input: ["n"])
            try await self.validateInstalledToolchains(
                Self.allToolchains,
                description: "abort uninstall"
            )

            // Ensure config did not change.
            XCTAssertEqual(try Config.load(), preConfig)
        }
    }
}
