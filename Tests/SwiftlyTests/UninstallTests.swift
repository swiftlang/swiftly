import Foundation
@testable import Swiftly
@testable import SwiftlyCore
import Testing

@Suite struct UninstallTests {
    static let homeName = "uninstallTests"

    /// Tests that `swiftly uninstall` successfully handles being invoked when no toolchains have been installed yet.
    @Test(.mockHomeToolchains(Self.homeName, toolchains: []), .mockedSwiftlyVersion()) func uninstallNoInstalledToolchains() async throws {
        _ = try await SwiftlyTests.runWithMockedIO(Uninstall.self, ["uninstall", "1.2.3"], input: ["y"])

        try await SwiftlyTests.validateInstalledToolchains(
            [],
            description: "remove not-installed toolchain"
        )
    }

    /// Tests that `swiftly uninstall latest` successfully uninstalls the latest stable release of Swift.
    @Test(.mockedSwiftlyVersion()) func uninstallLatest() async throws {
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
    @Test(.mockedSwiftlyVersion(), .mockHomeToolchains(Self.homeName)) func uninstallStableRelease() async throws {
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
    @Test(.mockedSwiftlyVersion(), .mockHomeToolchains(Self.homeName)) func uninstallSnapshot() async throws {
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
    @Test(.mockedSwiftlyVersion()) func bulkUninstall() async throws {
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
    @Test(.mockedSwiftlyVersion()) func uninstallInUse() async throws {
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
    @Test(.mockedSwiftlyVersion(), .mockHomeToolchains(Self.homeName, toolchains: [.oldStable])) func uninstallLastToolchain() async throws {
        _ = try await SwiftlyTests.runWithMockedIO(Uninstall.self, ["uninstall", ToolchainVersion.oldStable.name], input: ["y"])
        let config = try await Config.load()
        #expect(config.inUse == nil)

        // Ensure all symlinks have been cleaned up.
        let symlinks = try await fs.ls(
            atPath: Swiftly.currentPlatform.swiftlyBinDir(SwiftlyTests.ctx)
        )
        #expect(symlinks == [])
    }

    /// Tests that aborting an uninstall works correctly.
    @Test(.mockedSwiftlyVersion(), .mockHomeToolchains(Self.homeName, toolchains: .allToolchains(), inUse: .oldStable)) func uninstallAbort() async throws {
        let preConfig = try await Config.load()
        _ = try await SwiftlyTests.runWithMockedIO(Uninstall.self, ["uninstall", ToolchainVersion.oldStable.name], input: ["n"])
        try await SwiftlyTests.validateInstalledToolchains(
            .allToolchains(),
            description: "abort uninstall"
        )

        // Ensure config did not change.
        #expect(try await Config.load() == preConfig)
    }

    /// Tests that providing the `-y` argument skips the confirmation prompt.
    @Test(.mockedSwiftlyVersion(), .mockHomeToolchains(Self.homeName, toolchains: [.oldStable, .newStable])) func uninstallAssumeYes() async throws {
        try await SwiftlyTests.runCommand(Uninstall.self, ["uninstall", "-y", ToolchainVersion.oldStable.name])
        try await SwiftlyTests.validateInstalledToolchains(
            [.newStable],
            description: "uninstall did not succeed even with -y provided"
        )
    }

    /// Tests that providing "all" as an argument to uninstall will uninstall all toolchains.
    @Test(.mockedSwiftlyVersion(), .mockHomeToolchains(Self.homeName, toolchains: [.oldStable, .newStable, .newMainSnapshot, .oldReleaseSnapshot])) func uninstallAll() async throws {
        try await SwiftlyTests.runCommand(Uninstall.self, ["uninstall", "-y", "all"])
        try await SwiftlyTests.validateInstalledToolchains(
            [],
            description: "uninstall did not uninstall all toolchains"
        )
    }

    /// Tests that uninstalling a toolchain that is the global default, but is not in the list of installed toolchains.
    @Test(.mockedSwiftlyVersion(), .mockHomeToolchains(Self.homeName, toolchains: [.oldStable, .newStable, .newMainSnapshot, .oldReleaseSnapshot])) func uninstallNotInstalled() async throws {
        var config = try await Config.load()
        config.inUse = .newMainSnapshot
        config.installedToolchains.remove(.newMainSnapshot)
        try config.save()

        try await SwiftlyTests.runCommand(Uninstall.self, ["uninstall", "-y", ToolchainVersion.newMainSnapshot.name])
        try await SwiftlyTests.validateInstalledToolchains(
            [.oldStable, .newStable, .oldReleaseSnapshot],
            description: "uninstall did not uninstall all toolchains"
        )
    }

    @Test(.mockedSwiftlyVersion(), .mockHomeToolchains(Self.homeName, toolchains: [])) func uninstallXcode() async throws {
        let output = try await SwiftlyTests.runWithMockedIO(Uninstall.self, ["uninstall", "-y", ToolchainVersion.xcodeVersion.name])
        #expect(!output.filter { $0.contains("No toolchains can be uninstalled that match \"xcode\"") }.isEmpty)
    }

    // MARK: - Multiple Selector Tests

    /// Tests that multiple valid selectors work correctly
    @Test(.mockedSwiftlyVersion(), .mockHomeToolchains(Self.homeName, toolchains: [.oldStable, .newStable, .oldMainSnapshot, .newMainSnapshot]))
    func uninstallMultipleValidSelectors() async throws {
        let output = try await SwiftlyTests.runWithMockedIO(
            Uninstall.self,
            ["uninstall", ToolchainVersion.oldStable.name, ToolchainVersion.newMainSnapshot.name],
            input: ["y"]
        )

        // Verify both toolchains were uninstalled
        try await SwiftlyTests.validateInstalledToolchains(
            [.newStable, .oldMainSnapshot],
            description: "multiple valid selectors should uninstall both toolchains"
        )

        // Verify output shows confirmation message but no total summary
        #expect(output.contains { $0.contains("The following toolchains will be uninstalled:") })
        #expect(output.contains { $0.contains("Successfully uninstalled") && $0.contains("from 2 selector(s)") })
    }

    /// Tests deduplication when selectors overlap
    @Test(.mockedSwiftlyVersion())
    func uninstallOverlappingSelectors() async throws {
        // Set up test with stable releases that can overlap
        try await SwiftlyTests.withMockedHome(homeName: Self.homeName, toolchains: [.oldStable, .oldStableNewPatch]) {
            let output = try await SwiftlyTests.runWithMockedIO(
                Uninstall.self,
                ["uninstall", "5.6", ToolchainVersion.oldStable.name], // 5.6 selector matches both 5.6.0 and 5.6.3
                input: ["y"]
            )

            // Should uninstall both toolchains (5.6 matches both)
            try await SwiftlyTests.validateInstalledToolchains(
                [],
                description: "overlapping selectors should deduplicate correctly"
            )

            // Verify toolchains are shown in flat list format
            #expect(output.contains { $0.contains("The following toolchains will be uninstalled:") })
        }
    }

    /// Tests multiple selectors with progress indication
    @Test(.mockedSwiftlyVersion(), .mockHomeToolchains(Self.homeName, toolchains: [.oldStable, .newStable, .oldMainSnapshot]))
    func uninstallMultipleSelectorsProgress() async throws {
        let output = try await SwiftlyTests.runWithMockedIO(
            Uninstall.self,
            ["uninstall", "-y", ToolchainVersion.oldStable.name, ToolchainVersion.newStable.name, ToolchainVersion.oldMainSnapshot.name]
        )

        // Verify progress indicators appear
        #expect(output.contains { $0.contains("[1/3] Processing") })
        #expect(output.contains { $0.contains("[2/3] Processing") })
        #expect(output.contains { $0.contains("[3/3] Processing") })

        try await SwiftlyTests.validateInstalledToolchains(
            [],
            description: "multiple selectors with progress should uninstall all"
        )
    }

    // MARK: - Error Handling Tests

    /// Tests mixed valid and invalid selectors with user choice to proceed
    @Test(.mockedSwiftlyVersion(), .mockHomeToolchains(Self.homeName, toolchains: [.oldStable, .newStable]))
    func uninstallMixedValidInvalidSelectors() async throws {
        let output = try await SwiftlyTests.runWithMockedIO(
            Uninstall.self,
            ["uninstall", ToolchainVersion.oldStable.name, "invalid-selector", ToolchainVersion.newStable.name],
            input: ["y", "y"] // First y for error prompt, second y for confirmation
        )

        // Should show error about invalid selector
        #expect(output.contains { $0.contains("Invalid toolchain selectors: invalid-selector") })

        // Should ask user if they want to proceed with valid ones
        #expect(output.contains { $0.contains("Found 2 toolchain(s) from valid selectors. Continue") })

        // Should uninstall the valid ones
        try await SwiftlyTests.validateInstalledToolchains(
            [],
            description: "should proceed with valid selectors after user confirmation"
        )
    }

    /// Tests mixed valid and invalid selectors with user choice to abort
    @Test(.mockedSwiftlyVersion(), .mockHomeToolchains(Self.homeName, toolchains: [.oldStable, .newStable]))
    func uninstallMixedValidInvalidSelectorsAbort() async throws {
        let output = try await SwiftlyTests.runWithMockedIO(
            Uninstall.self,
            ["uninstall", ToolchainVersion.oldStable.name, "invalid-selector"],
            input: ["n"] // Abort at error prompt
        )

        // Should show error and abort
        #expect(output.contains { $0.contains("Invalid toolchain selectors: invalid-selector") })
        #expect(output.contains { $0.contains("Aborting uninstall") })

        // Should not uninstall anything
        try await SwiftlyTests.validateInstalledToolchains(
            [.oldStable, .newStable],
            description: "should not uninstall anything when user aborts"
        )
    }

    /// Tests selectors with no matches
    @Test(.mockedSwiftlyVersion(), .mockHomeToolchains(Self.homeName, toolchains: [.oldStable]))
    func uninstallNoMatchSelectors() async throws {
        let output = try await SwiftlyTests.runWithMockedIO(
            Uninstall.self,
            ["uninstall", "main-snapshot", "5.99.0"] // Neither installed
        )

        #expect(output.contains { $0.contains("No toolchains match these selectors: main-snapshot, 5.99.0") })
        #expect(output.contains { $0.contains("No valid toolchains found to uninstall") })

        // Nothing should be uninstalled
        try await SwiftlyTests.validateInstalledToolchains(
            [.oldStable],
            description: "no-match selectors should not uninstall anything"
        )
    }

    /// Tests all invalid selectors
    @Test(.mockedSwiftlyVersion(), .mockHomeToolchains(Self.homeName, toolchains: [.oldStable]))
    func uninstallAllInvalidSelectors() async throws {
        let output = try await SwiftlyTests.runWithMockedIO(
            Uninstall.self,
            ["uninstall", "invalid-1", "invalid-2"]
        )

        #expect(output.contains { $0.contains("Invalid toolchain selectors: invalid-1, invalid-2") })
        #expect(output.contains { $0.contains("No valid toolchains found to uninstall") })

        try await SwiftlyTests.validateInstalledToolchains(
            [.oldStable],
            description: "all invalid selectors should not uninstall anything"
        )
    }

    // MARK: - Edge Cases

    /// Tests multiple selectors where some result in empty matches after filtering
    @Test(.mockedSwiftlyVersion(), .mockHomeToolchains(Self.homeName, toolchains: [.oldStable]))
    func uninstallMultipleSelectorsFiltered() async throws {
        let output = try await SwiftlyTests.runWithMockedIO(
            Uninstall.self,
            ["uninstall", ToolchainVersion.oldStable.name, "xcode"], // xcode gets filtered out
            input: ["y"]
        )

        // Should only uninstall the valid, non-filtered toolchain
        try await SwiftlyTests.validateInstalledToolchains(
            [],
            description: "should handle filtering correctly"
        )

        // Should show multiple selector completion message since we provided 2 selectors
        #expect(output.contains { $0.contains("The following toolchains will be uninstalled:") })
        #expect(output.contains { $0.contains("Successfully uninstalled 1 toolchain(s) from 2 selector(s)") })
    }

    /// Tests multiple selectors with in-use toolchain replacement
    @Test(.mockedSwiftlyVersion(), .mockHomeToolchains(Self.homeName, toolchains: [.oldStable, .newStable, .oldMainSnapshot], inUse: .oldStable))
    func uninstallMultipleSelectorsInUse() async throws {
        let output = try await SwiftlyTests.runWithMockedIO(
            Uninstall.self,
            ["uninstall", "-y", ToolchainVersion.oldStable.name, ToolchainVersion.oldMainSnapshot.name]
        )

        // Should uninstall both
        try await SwiftlyTests.validateInstalledToolchains(
            [.newStable],
            description: "should uninstall multiple including in-use"
        )

        // Should switch to newStable since oldStable was in-use and got uninstalled
        try await SwiftlyTests.validateInUse(expected: .newStable)

        // Should show progress for multiple toolchains
        #expect(output.contains { $0.contains("[1/2] Processing") })
        #expect(output.contains { $0.contains("[2/2] Processing") })
    }
}
