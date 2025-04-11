import Foundation
@testable import Swiftly
@testable import SwiftlyCore
import Testing

@Suite struct UninstallTests {
    static let homeName = "uninstallTests"

    /// Tests that `swiftly uninstall` successfully handles being invoked when no toolchains have been installed yet.
    @Test(.mockHomeToolchains(Self.homeName, toolchains: [])) func uninstallNoInstalledToolchains() async throws {
        _ = try await SwiftlyTests.runWithMockedIO(Uninstall.self, ["uninstall", "1.2.3"], input: ["y"])

        try await SwiftlyTests.validateInstalledToolchains(
            [],
            description: "remove not-installed toolchain"
        )
    }

    /// Tests that `swiftly uninstall latest` successfully uninstalls the latest stable release of Swift.
    @Test func uninstallLatest() async throws {
        let toolchains = Set<ToolchainVersion>.allToolchains().filter { $0.asStableRelease != nil }
        try await SwiftlyTests.withMockedHome(homeName: Self.homeName, toolchains: toolchains) {
            var installed = toolchains

            for i in 0..<toolchains.count {
                _ = try await SwiftlyTests.runWithMockedIO(Uninstall.self, ["uninstall", "latest"], input: ["y"])
                installed.remove(installed.max()!)

                try await SwiftlyTests.validateInstalledToolchains(
                    installed,
                    description: "remove latest \(i)"
                )
            }

            // Ensure that uninstalling when no toolchains are installed is handled gracefully.
            try await SwiftlyTests.runCommand(Uninstall.self, ["uninstall", "latest"])
        }
    }

    /// Tests that a fully-qualified stable release version can be supplied to `swiftly uninstall`.
    @Test(.mockHomeToolchains(Self.homeName)) func uninstallStableRelease() async throws {
        var installed: Set<ToolchainVersion> = .allToolchains()

        for toolchain in Set<ToolchainVersion>.allToolchains().filter({ $0.isStableRelease() }) {
            _ = try await SwiftlyTests.runWithMockedIO(Uninstall.self, ["uninstall", toolchain.name], input: ["y"])
            installed.remove(toolchain)

            try await SwiftlyTests.validateInstalledToolchains(
                installed,
                description: "remove \(toolchain)"
            )
        }

        _ = try await SwiftlyTests.runWithMockedIO(Uninstall.self, ["uninstall", "1.2.3"], input: ["y"])

        try await SwiftlyTests.validateInstalledToolchains(
            installed,
            description: "remove not-installed toolchain"
        )
    }

    /// Tests that a fully-qualified snapshot version can be supplied to `swiftly uninstall`.
    @Test(.mockHomeToolchains(Self.homeName)) func uninstallSnapshot() async throws {
        var installed: Set<ToolchainVersion> = .allToolchains()

        for toolchain in Set<ToolchainVersion>.allToolchains().filter({ $0.isSnapshot() }) {
            _ = try await SwiftlyTests.runWithMockedIO(Uninstall.self, ["uninstall", toolchain.name], input: ["y"])
            installed.remove(toolchain)

            try await SwiftlyTests.validateInstalledToolchains(
                installed,
                description: "remove \(toolchain)"
            )
        }

        _ = try await SwiftlyTests.runWithMockedIO(Uninstall.self, ["uninstall", "main-snapshot-2022-01-01"], input: ["y"])

        try await SwiftlyTests.validateInstalledToolchains(
            installed,
            description: "remove not-installed toolchain"
        )
    }

    /// Tests that multiple toolchains can be installed at once.
    @Test func bulkUninstall() async throws {
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
            let output = try await SwiftlyTests.runWithMockedIO(Uninstall.self, ["uninstall", argument], input: ["y"])
            installed.subtract(uninstalled)
            try await SwiftlyTests.validateInstalledToolchains(
                installed,
                description: "uninstall \(argument)"
            )
            // Ensure that swiftly checks for confirmation before uninstalling all toolchains.
            let outputToolchains = output.compactMap {
                try? ToolchainVersion(parsing: $0.trimmingCharacters(in: .whitespaces))
            }
            #expect(Set(outputToolchains) == uninstalled)
        }

        try await SwiftlyTests.withMockedHome(homeName: Self.homeName, toolchains: Set(toolchains)) {
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
    @Test func uninstallInUse() async throws {
        let toolchains: Set<ToolchainVersion> = [
            .oldStable,
            .oldStableNewPatch,
            .newStable,
            .oldMainSnapshot,
            .newMainSnapshot,
            .oldReleaseSnapshot,
            .newReleaseSnapshot,
        ]

        func uninstallInUseTest(
            _ installed: inout Set<ToolchainVersion>,
            toRemove: ToolchainVersion,
            expectedInUse: ToolchainVersion?
        ) async throws {
            let output = try await SwiftlyTests.runWithMockedIO(Uninstall.self, ["uninstall", toRemove.name], input: ["y"])
            installed.remove(toRemove)
            try await SwiftlyTests.validateInstalledToolchains(
                installed,
                description: "remove \(toRemove)"
            )

            // Ensure the latest installed toolchain was used when the in-use one was uninstalled.
            try await SwiftlyTests.validateInUse(expected: expectedInUse)

            if let expectedInUse {
                // Ensure that something was printed indicating the latest toolchain was marked in use.
                #expect(
                    output.contains(where: { $0.contains(String(describing: expectedInUse)) }),
                    "output did not contain \(expectedInUse)"
                )
            }
        }

        try await SwiftlyTests.withMockedHome(homeName: Self.homeName, toolchains: toolchains, inUse: .oldStable) {
            var installed = toolchains

            try await uninstallInUseTest(&installed, toRemove: .oldStable, expectedInUse: .oldStableNewPatch)
            try await uninstallInUseTest(&installed, toRemove: .oldStableNewPatch, expectedInUse: .newStable)
            try await uninstallInUseTest(&installed, toRemove: .newStable, expectedInUse: .newMainSnapshot)

            // Switch to the old main snapshot to ensure uninstalling it selects the new one.
            try await SwiftlyTests.runCommand(Use.self, ["use", ToolchainVersion.oldMainSnapshot.name])
            try await uninstallInUseTest(&installed, toRemove: .oldMainSnapshot, expectedInUse: .newMainSnapshot)
            try await uninstallInUseTest(
                &installed,
                toRemove: .newMainSnapshot,
                expectedInUse: .newReleaseSnapshot
            )
            // Switch to the old release snapshot to ensure uninstalling it selects the new one.
            try await SwiftlyTests.runCommand(Use.self, ["use", ToolchainVersion.oldReleaseSnapshot.name])
            try await uninstallInUseTest(
                &installed,
                toRemove: .oldReleaseSnapshot,
                expectedInUse: .newReleaseSnapshot
            )
            try await uninstallInUseTest(
                &installed,
                toRemove: .newReleaseSnapshot,
                expectedInUse: nil
            )
        }
    }

    /// Tests that uninstalling the last toolchain is handled properly and cleans up any symlinks.
    @Test(.mockHomeToolchains(Self.homeName, toolchains: [.oldStable])) func uninstallLastToolchain() async throws {
        _ = try await SwiftlyTests.runWithMockedIO(Uninstall.self, ["uninstall", ToolchainVersion.oldStable.name], input: ["y"])
        let config = try Config.load()
        #expect(config.inUse == nil)

        // Ensure all symlinks have been cleaned up.
        let symlinks = try FileManager.default.contentsOfDirectory(
            atPath: Swiftly.currentPlatform.swiftlyBinDir(SwiftlyTests.ctx).path
        )
        #expect(symlinks == [])
    }

    /// Tests that aborting an uninstall works correctly.
    @Test(.mockHomeToolchains(Self.homeName, toolchains: .allToolchains(), inUse: .oldStable)) func uninstallAbort() async throws {
        let preConfig = try Config.load()
        _ = try await SwiftlyTests.runWithMockedIO(Uninstall.self, ["uninstall", ToolchainVersion.oldStable.name], input: ["n"])
        try await SwiftlyTests.validateInstalledToolchains(
            .allToolchains(),
            description: "abort uninstall"
        )

        // Ensure config did not change.
        #expect(try Config.load() == preConfig)
    }

    /// Tests that providing the `-y` argument skips the confirmation prompt.
    @Test(.mockHomeToolchains(Self.homeName, toolchains: [.oldStable, .newStable])) func uninstallAssumeYes() async throws {
        try await SwiftlyTests.runCommand(Uninstall.self, ["uninstall", "-y", ToolchainVersion.oldStable.name])
        try await SwiftlyTests.validateInstalledToolchains(
            [.newStable],
            description: "uninstall did not succeed even with -y provided"
        )
    }

    /// Tests that providing "all" as an argument to uninstall will uninstall all toolchains.
    @Test(.mockHomeToolchains(Self.homeName, toolchains: [.oldStable, .newStable, .newMainSnapshot, .oldReleaseSnapshot])) func uninstallAll() async throws {
        try await SwiftlyTests.runCommand(Uninstall.self, ["uninstall", "-y", "all"])
        try await SwiftlyTests.validateInstalledToolchains(
            [],
            description: "uninstall did not uninstall all toolchains"
        )
    }

    /// Tests that uninstalling a toolchain that is the global default, but is not in the list of installed toolchains.
    @Test(.mockHomeToolchains(Self.homeName, toolchains: [.oldStable, .newStable, .newMainSnapshot, .oldReleaseSnapshot])) func uninstallNotInstalled() async throws {
        var config = try Config.load()
        config.inUse = .newMainSnapshot
        config.installedToolchains.remove(.newMainSnapshot)
        try config.save()

        try await SwiftlyTests.runCommand(Uninstall.self, ["uninstall", "-y", ToolchainVersion.newMainSnapshot.name])
        try await SwiftlyTests.validateInstalledToolchains(
            [.oldStable, .newStable, .oldReleaseSnapshot],
            description: "uninstall did not uninstall all toolchains"
        )
    }

    @Test(.mockHomeToolchains(Self.homeName, toolchains: [])) func uninstallXcode() async throws {
        let output = try await SwiftlyTests.runWithMockedIO(Uninstall.self, ["uninstall", "-y", ToolchainVersion.xcodeVersion.name])
        #expect(!output.filter { $0.contains("No toolchains can be uninstalled that match \"xcode\"") }.isEmpty)
    }
}
