import Foundation
@testable import Swiftly
@testable import SwiftlyCore
import Testing

@Suite struct InstallTests {
    /// Tests that `swiftly install latest` successfully installs the latest stable release of Swift.
    ///
    /// It stops short of verifying that it actually installs the _most_ recently released version, which is the intended
    /// behavior, since determining which version is the latest is non-trivial and would require duplicating code
    /// from within swiftly itself.
    @Test(.testHomeMockedToolchain()) func installLatest() async throws {
        try await SwiftlyTests.runCommand(Install.self, ["install", "latest", "--post-install-file=\(fs.mktemp())"])

        let config = try await Config.load()

        guard !config.installedToolchains.isEmpty else {
            Issue.record("expected to install latest main snapshot toolchain but installed toolchains is empty in the config")
            return
        }

        let installedToolchain = config.installedToolchains.first!

        guard case let .stable(release) = installedToolchain else {
            Issue.record("expected swiftly install latest to install release toolchain but got \(installedToolchain)")
            return
        }

        // As of writing this, 5.8.0 is the latest stable release. Assert it is at least that new.
        #expect(release >= ToolchainVersion.StableRelease(major: 5, minor: 8, patch: 0))

        try await SwiftlyTests.validateInstalledToolchains([installedToolchain], description: "install latest")
    }

    /// Tests that `swiftly install a.b` installs the latest patch version of Swift a.b.
    @Test(.testHomeMockedToolchain()) func installLatestPatchVersion() async throws {
        try await SwiftlyTests.runCommand(Install.self, ["install", "5.7", "--post-install-file=\(fs.mktemp())"])

        let config = try await Config.load()

        guard !config.installedToolchains.isEmpty else {
            Issue.record("expected swiftly install latest to install release toolchain but installed toolchains is empty in config")
            return
        }

        let installedToolchain = config.installedToolchains.first!

        guard case let .stable(release) = installedToolchain else {
            Issue.record("expected swiftly install latest to install release toolchain but got \(installedToolchain)")
            return
        }

        // As of writing this, 5.7.3 is the latest 5.7 patch release. Assert it is at least that new.
        #expect(release >= ToolchainVersion.StableRelease(major: 5, minor: 7, patch: 3))

        try await SwiftlyTests.validateInstalledToolchains([installedToolchain], description: "install latest")
    }

    /// Tests that swiftly can install different stable release versions by their full a.b.c versions.
    @Test(.testHomeMockedToolchain()) func installReleases() async throws {
        var installedToolchains: Set<ToolchainVersion> = []

        try await SwiftlyTests.runCommand(Install.self, ["install", "5.7.0", "--post-install-file=\(fs.mktemp())"])

        installedToolchains.insert(ToolchainVersion(major: 5, minor: 7, patch: 0))
        try await SwiftlyTests.validateInstalledToolchains(
            installedToolchains,
            description: "install a stable release toolchain"
        )

        try await SwiftlyTests.runCommand(Install.self, ["install", "5.7.2", "--post-install-file=\(fs.mktemp())"])

        installedToolchains.insert(ToolchainVersion(major: 5, minor: 7, patch: 2))
        try await SwiftlyTests.validateInstalledToolchains(
            installedToolchains,
            description: "install another stable release toolchain"
        )
    }

    /// Tests that swiftly can install main and release snapshots by their full snapshot names.
    @Test(.testHomeMockedToolchain()) func installSnapshots() async throws {
        var installedToolchains: Set<ToolchainVersion> = []

        try await SwiftlyTests.runCommand(Install.self, ["install", "main-snapshot-2023-04-01", "--post-install-file=\(fs.mktemp())"])

        installedToolchains.insert(ToolchainVersion(snapshotBranch: .main, date: "2023-04-01"))
        try await SwiftlyTests.validateInstalledToolchains(
            installedToolchains,
            description: "install a main snapshot toolchain"
        )

        try await SwiftlyTests.runCommand(Install.self, ["install", "5.9-snapshot-2023-04-01", "--post-install-file=\(fs.mktemp())"])

        installedToolchains.insert(
            ToolchainVersion(snapshotBranch: .release(major: 5, minor: 9), date: "2023-04-01"))
        try await SwiftlyTests.validateInstalledToolchains(
            installedToolchains,
            description: "install a 5.9 snapshot toolchain"
        )
    }

    /// Tests that `swiftly install main-snapshot` installs the latest available main snapshot.
    @Test(.testHomeMockedToolchain()) func installLatestMainSnapshot() async throws {
        try await SwiftlyTests.runCommand(Install.self, ["install", "main-snapshot", "--post-install-file=\(fs.mktemp())"])

        let config = try await Config.load()

        guard !config.installedToolchains.isEmpty else {
            Issue.record("expected to install latest main snapshot toolchain but installed toolchains is empty in the config")
            return
        }

        let installedToolchain = config.installedToolchains.first!

        guard case let .snapshot(snapshot) = installedToolchain, snapshot.branch == .main else {
            Issue.record("expected to install latest main snapshot toolchain but got \(installedToolchain)")
            return
        }

        // As of writing this, this is the date of the latest main snapshot. Assert it is at least that new.
        #expect(snapshot.date >= "2023-04-01")

        try await SwiftlyTests.validateInstalledToolchains(
            [installedToolchain],
            description: "install the latest main snapshot toolchain"
        )
    }

    /// Tests that `swiftly install a.b-snapshot` installs the latest available a.b release snapshot.
    @Test(.testHomeMockedToolchain()) func installLatestReleaseSnapshot() async throws {
        try await SwiftlyTests.runCommand(Install.self, ["install", "6.0-snapshot", "--post-install-file=\(fs.mktemp())"])

        let config = try await Config.load()

        guard !config.installedToolchains.isEmpty else {
            Issue.record("expected to install latest main snapshot toolchain but installed toolchains is empty in the config")
            return
        }

        let installedToolchain = config.installedToolchains.first!

        guard case let .snapshot(snapshot) = installedToolchain, snapshot.branch == .release(major: 6, minor: 0) else {
            Issue.record("expected swiftly install 6.0-snapshot to install snapshot toolchain but got \(installedToolchain)")
            return
        }

        // As of writing this, this is the date of the latest 5.7 snapshot. Assert it is at least that new.
        #expect(snapshot.date >= "2024-06-18")

        try await SwiftlyTests.validateInstalledToolchains(
            [installedToolchain],
            description: "install the latest 6.0 snapshot toolchain"
        )
    }

    /// Tests that swiftly can install both stable release toolchains and snapshot toolchains.
    @Test(.testHomeMockedToolchain()) func installReleaseAndSnapshots() async throws {
        try await SwiftlyTests.runCommand(Install.self, ["install", "main-snapshot-2023-04-01", "--post-install-file=\(fs.mktemp())"])

        try await SwiftlyTests.runCommand(Install.self, ["install", "5.9-snapshot-2023-03-28", "--post-install-file=\(fs.mktemp())"])

        try await SwiftlyTests.runCommand(Install.self, ["install", "5.8.0", "--post-install-file=\(fs.mktemp())"])

        try await SwiftlyTests.validateInstalledToolchains(
            [
                ToolchainVersion(snapshotBranch: .main, date: "2023-04-01"),
                ToolchainVersion(snapshotBranch: .release(major: 5, minor: 9), date: "2023-03-28"),
                ToolchainVersion(major: 5, minor: 8, patch: 0),
            ],
            description: "install both snapshots and releases"
        )
    }

    func duplicateTest(_ version: String) async throws {
        try await SwiftlyTests.withTestHome {
            try await SwiftlyTests.withMockedToolchain {
                try await SwiftlyTests.runCommand(Install.self, ["install", version, "--post-install-file=\(fs.mktemp())"])

                let before = try await Config.load()

                let startTime = Date()
                try await SwiftlyTests.runCommand(Install.self, ["install", version, "--post-install-file=\(fs.mktemp())"])

                // Assert that swiftly didn't attempt to download a new toolchain.
                #expect(startTime.timeIntervalSinceNow.magnitude < 10)

                let after = try await Config.load()
                #expect(before == after)
            }
        }
    }

    /// Tests that attempting to install stable releases that are already installed doesn't result in an error.
    @Test(.testHomeMockedToolchain(), arguments: ["5.8.0", "latest"]) func installDuplicateReleases(_ installVersion: String) async throws {
        try await SwiftlyTests.runCommand(Install.self, ["install", installVersion, "--post-install-file=\(fs.mktemp())"])

        let before = try await Config.load()

        let startTime = Date()
        try await SwiftlyTests.runCommand(Install.self, ["install", installVersion, "--post-install-file=\(fs.mktemp())"])

        // Assert that swiftly didn't attempt to download a new toolchain.
        #expect(startTime.timeIntervalSinceNow.magnitude < 10)

        let after = try await Config.load()
        #expect(before == after)
    }

    /// Tests that attempting to install main snapshots that are already installed doesn't result in an error.
    @Test(.testHomeMockedToolchain(), arguments: ["main-snapshot-2023-04-01", "main-snapshot"]) func installDuplicateMainSnapshots(_ installVersion: String) async throws {
        try await SwiftlyTests.runCommand(Install.self, ["install", installVersion, "--post-install-file=\(fs.mktemp())"])

        let before = try await Config.load()

        let startTime = Date()
        try await SwiftlyTests.runCommand(Install.self, ["install", installVersion, "--post-install-file=\(fs.mktemp())"])

        // Assert that swiftly didn't attempt to download a new toolchain.
        #expect(startTime.timeIntervalSinceNow.magnitude < 10)

        let after = try await Config.load()
        #expect(before == after)
    }

    /// Tests that attempting to install release snapshots that are already installed doesn't result in an error.
    @Test(.testHomeMockedToolchain(), arguments: ["6.0-snapshot-2024-06-18", "6.0-snapshot"]) func installDuplicateReleaseSnapshots(_ installVersion: String) async throws {
        try await SwiftlyTests.runCommand(Install.self, ["install", installVersion, "--post-install-file=\(fs.mktemp())"])

        let before = try await Config.load()

        let startTime = Date()
        try await SwiftlyTests.runCommand(Install.self, ["install", installVersion, "--post-install-file=\(fs.mktemp())"])

        // Assert that swiftly didn't attempt to download a new toolchain.
        #expect(startTime.timeIntervalSinceNow.magnitude < 10)

        let after = try await Config.load()
        #expect(before == after)
    }

    /// Verify that the installed toolchain will be used if no toolchains currently are installed.
    @Test(.testHomeMockedToolchain()) func installUsesFirstToolchain() async throws {
        let config = try await Config.load()
        #expect(config.inUse == nil)
        try await SwiftlyTests.validateInUse(expected: nil)

        try await SwiftlyTests.runCommand(Install.self, ["install", "5.7.0", "--post-install-file=\(fs.mktemp())"])

        try await SwiftlyTests.validateInUse(expected: ToolchainVersion(major: 5, minor: 7, patch: 0))

        try await SwiftlyTests.runCommand(Install.self, ["install", "5.7.1", "--post-install-file=\(fs.mktemp())"])

        // Verify that 5.7.0 is still in use.
        try await SwiftlyTests.validateInUse(expected: ToolchainVersion(major: 5, minor: 7, patch: 0))
    }

    /// Verify that the installed toolchain will be marked as in-use if the --use flag is specified.
    @Test(.testHomeMockedToolchain()) func installUseFlag() async throws {
        try await SwiftlyTests.installMockedToolchain(toolchain: .oldStable)
        try await SwiftlyTests.runCommand(Use.self, ["use", ToolchainVersion.oldStable.name])
        try await SwiftlyTests.validateInUse(expected: .oldStable)
        try await SwiftlyTests.installMockedToolchain(selector: ToolchainVersion.newStable.name, args: ["--use"])
        try await SwiftlyTests.validateInUse(expected: .newStable)
    }
}
