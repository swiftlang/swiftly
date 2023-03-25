import Foundation
@testable import Swiftly
@testable import SwiftlyCore
import XCTest

final class UninstallTests: SwiftlyTests {
    static let homeName = "uninstallTests"

    /// Tests that `swiftly uninstall` successfully handles being invoked when no toolchains have been installed yet.
    func testUninstallNoInstalledToolchains() async throws {
        try await self.withMockedHome(homeName: Self.homeName, toolchains: []) {
            var uninstall = try self.parseCommand(Uninstall.self, ["uninstall", "1.2.3"])
            _ = try await uninstall.runWithMockedIO(input: ["y"])

            try await self.validateInstalledToolchains(
                [],
                description: "remove not-installed toolchain"
            )
        }
    }

    /// Tests that `swiftly uninstall latest` successfully uninstalls the latest stable release of Swift.
    func testUninstallLatest() async throws {
        let toolchains = Self.allToolchains.filter { $0.asStableRelease != nil }
        try await self.withMockedHome(homeName: Self.homeName, toolchains: toolchains) {
            var installed = toolchains

            for i in 0..<toolchains.count {
                var uninstall = try self.parseCommand(Uninstall.self, ["uninstall", "latest"])
                _ = try await uninstall.runWithMockedIO(input: ["y"])
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

    /// Tests that a fully-qualified stable release version can be supplied to `swiftly uninstall`.
    func testUninstallStableRelease() async throws {
        try await self.withMockedHome(homeName: Self.homeName, toolchains: Self.allToolchains) {
            var installed = Self.allToolchains

            for toolchain in Self.allToolchains.filter({ $0.isStableRelease() }) {
                var uninstall = try self.parseCommand(Uninstall.self, ["uninstall", toolchain.name])
                _ = try await uninstall.runWithMockedIO(input: ["y"])
                installed.remove(toolchain)

                try await self.validateInstalledToolchains(
                    installed,
                    description: "remove \(toolchain)"
                )
            }

            var uninstall = try self.parseCommand(Uninstall.self, ["uninstall", "1.2.3"])
            _ = try await uninstall.runWithMockedIO(input: ["y"])

            try await self.validateInstalledToolchains(
                installed,
                description: "remove not-installed toolchain"
            )
        }
    }

    /// Tests that a fully-qualified snapshot version can be supplied to `swiftly uninstall`.
    func testUninstallSnapshot() async throws {
        try await self.withMockedHome(homeName: Self.homeName, toolchains: Self.allToolchains) {
            var installed = Self.allToolchains

            for toolchain in Self.allToolchains.filter({ $0.isSnapshot() }) {
                var uninstall = try self.parseCommand(Uninstall.self, ["uninstall", toolchain.name])
                _ = try await uninstall.runWithMockedIO(input: ["y"])
                installed.remove(toolchain)

                try await self.validateInstalledToolchains(
                    installed,
                    description: "remove \(toolchain)"
                )
            }

            var uninstall = try self.parseCommand(Uninstall.self, ["uninstall", "main-snapshot-2022-01-01"])
            _ = try await uninstall.runWithMockedIO(input: ["y"])

            try await self.validateInstalledToolchains(
                installed,
                description: "remove not-installed toolchain"
            )
        }
    }

    /// Tests that multiple toolchains can be installed at once.
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
                "1.5.54",
            ].map { try! ToolchainVersion(parsing: $0) }
        )

        func bulkUninstallTest(
            installed: inout Set<ToolchainVersion>,
            argument: String,
            uninstalled: Set<ToolchainVersion>
        ) async throws {
            var uninstall = try self.parseCommand(Uninstall.self, ["uninstall", argument])
            let output = try await uninstall.runWithMockedIO(input: ["y"])
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

    /// Tests that uninstalling the toolchain that is currently "in use" has the expected behavior.
    func testUninstallInUse() async throws {
        let toolchains: Set<ToolchainVersion> = [
            Self.oldStable,
            Self.oldStableNewPatch,
            Self.newStable,
            Self.oldMainSnapshot,
            Self.newMainSnapshot,
            Self.oldReleaseSnapshot,
            Self.newReleaseSnapshot,
        ]

        func uninstallInUseTest(
            _ installed: inout Set<ToolchainVersion>,
            toRemove: ToolchainVersion,
            expectedInUse: ToolchainVersion?
        ) async throws {
            var uninstall = try self.parseCommand(Uninstall.self, ["uninstall", toRemove.name])
            let output = try await uninstall.runWithMockedIO(input: ["y"])
            installed.remove(toRemove)
            try await self.validateInstalledToolchains(
                installed,
                description: "remove \(toRemove)"
            )

            // Ensure the latest installed toolchain was used when the in-use one was uninstalled.
            try await self.validateInUse(expected: expectedInUse)

            if let expectedInUse {
                // Ensure that something was printed indicating the latest toolchain was marked in use.
                XCTAssert(
                    output.contains(where: { $0.contains(String(describing: expectedInUse)) }),
                    "output did not contain \(expectedInUse)"
                )
            }
        }

        try await self.withMockedHome(homeName: Self.homeName, toolchains: toolchains, inUse: Self.oldStable) {
            var installed = toolchains

            try await uninstallInUseTest(&installed, toRemove: Self.oldStable, expectedInUse: Self.oldStableNewPatch)
            try await uninstallInUseTest(&installed, toRemove: Self.oldStableNewPatch, expectedInUse: Self.newStable)
            try await uninstallInUseTest(&installed, toRemove: Self.newStable, expectedInUse: Self.newMainSnapshot)

            // Switch to the old main snapshot to ensure uninstalling it selects the new one.
            var use = try self.parseCommand(Use.self, ["use", Self.oldMainSnapshot.name])
            try await use.run()
            try await uninstallInUseTest(&installed, toRemove: Self.oldMainSnapshot, expectedInUse: Self.newMainSnapshot)
            try await uninstallInUseTest(
                &installed,
                toRemove: Self.newMainSnapshot,
                expectedInUse: Self.newReleaseSnapshot
            )
            // Switch to the old release snapshot to ensure uninstalling it selects the new one.
            use = try self.parseCommand(Use.self, ["use", Self.oldReleaseSnapshot.name])
            try await use.run()
            try await uninstallInUseTest(
                &installed,
                toRemove: Self.oldReleaseSnapshot,
                expectedInUse: Self.newReleaseSnapshot
            )
            try await uninstallInUseTest(
                &installed,
                toRemove: Self.newReleaseSnapshot,
                expectedInUse: nil
            )
        }
    }

    /// Tests that uninstalling the last toolchain is handled properly and cleans up any symlinks.
    func testUninstallLastToolchain() async throws {
        try await self.withMockedHome(homeName: Self.homeName, toolchains: [Self.oldStable], inUse: Self.oldStable) {
            var uninstall = try self.parseCommand(Uninstall.self, ["uninstall", Self.oldStable.name])
            _ = try await uninstall.runWithMockedIO(input: ["y"])
            let config = try Config.load()
            XCTAssertEqual(config.inUse, nil)

            // Ensure all symlinks have been cleaned up.
            let symlinks = try FileManager.default.contentsOfDirectory(
                atPath: Swiftly.currentPlatform.swiftlyBinDir.path
            )
            XCTAssertEqual(symlinks, [])
        }
    }

    /// Tests that aborting an uninstall works correctly.
    func testUninstallAbort() async throws {
        try await self.withMockedHome(homeName: Self.homeName, toolchains: Self.allToolchains, inUse: Self.oldStable) {
            let preConfig = try Config.load()
            var uninstall = try self.parseCommand(Uninstall.self, ["uninstall", Self.oldStable.name])
            _ = try await uninstall.runWithMockedIO(input: ["n"])
            try await self.validateInstalledToolchains(
                Self.allToolchains,
                description: "abort uninstall"
            )

            // Ensure config did not change.
            XCTAssertEqual(try Config.load(), preConfig)
        }
    }

    /// Tests that providing the `-y` argument skips the confirmation prompt.
    func testUninstallAssumeYes() async throws {
        try await self.withMockedHome(homeName: Self.homeName, toolchains: [Self.oldStable, Self.newStable]) {
            var uninstall = try self.parseCommand(Uninstall.self, ["uninstall", "-y", Self.oldStable.name])
            _ = try await uninstall.run()
            try await self.validateInstalledToolchains(
                [Self.newStable],
                description: "uninstall did not succeed even with -y provided"
            )
        }
    }
}
