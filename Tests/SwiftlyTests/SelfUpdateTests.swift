import AsyncHTTPClient
import Foundation
import NIO
import OpenAPIRuntime
@testable import Swiftly
@testable import SwiftlyCore
import SwiftlyWebsiteAPI
import Testing

/// Wraps MockToolchainDownloader and tracks how many times getCurrentSwiftlyRelease is called.
private final actor UpdateCheckTracker: HTTPRequestExecutor {
    var updateCheckCount = 0
    private let base: MockToolchainDownloader

    init(latestSwiftlyVersion: SwiftlyVersion = SwiftlyCore.version) {
        self.base = MockToolchainDownloader(latestSwiftlyVersion: latestSwiftlyVersion)
    }

    func getCurrentSwiftlyRelease() async throws -> Components.Schemas.SwiftlyRelease {
        self.updateCheckCount += 1
        return try await self.base.getCurrentSwiftlyRelease()
    }

    func getReleaseToolchains() async throws -> [Components.Schemas.Release] { try await self.base.getReleaseToolchains() }
    func getSnapshotToolchains(branch: Components.Schemas.SourceBranch, platform: Components.Schemas.PlatformIdentifier) async throws -> Components.Schemas.DevToolchains { try await self.base.getSnapshotToolchains(branch: branch, platform: platform) }
    func getGpgKeys() async throws -> HTTPBody { try await self.base.getGpgKeys() }
    func getSwiftlyRelease(url: URL) async throws -> HTTPBody { try await self.base.getSwiftlyRelease(url: url) }
    func getSwiftlyReleaseSignature(url: URL) async throws -> HTTPBody { try await self.base.getSwiftlyReleaseSignature(url: url) }
    func getSwiftToolchainFile(_ toolchainFile: ToolchainFile) async throws -> HTTPBody { try await self.base.getSwiftToolchainFile(toolchainFile) }
    func getSwiftToolchainFileSignature(_ toolchainFile: ToolchainFile) async throws -> HTTPBody { try await self.base.getSwiftToolchainFileSignature(toolchainFile) }
}

@Suite struct SelfUpdateTests {
    private static var newMajorVersion: SwiftlyVersion {
        SwiftlyVersion(major: SwiftlyCore.version.major + 1, minor: 0, patch: 0)
    }

    private static var newMinorVersion: SwiftlyVersion {
        SwiftlyVersion(major: SwiftlyCore.version.major, minor: SwiftlyCore.version.minor + 1, patch: 0)
    }

    private static var newPatchVersion: SwiftlyVersion {
        SwiftlyVersion(major: SwiftlyCore.version.major, minor: SwiftlyCore.version.minor, patch: SwiftlyCore.version.patch + 1)
    }

    private static var newDevVersion: SwiftlyVersion {
        SwiftlyVersion(major: SwiftlyCore.version.major, minor: SwiftlyCore.version.minor, patch: SwiftlyCore.version.patch + 1, suffix: "dev")
    }

    func runSelfUpdateTest(latestVersion: SwiftlyVersion) async throws {
        try await SwiftlyTests.withTestHome {
            try await SwiftlyTests.withMockedSwiftlyVersion(latestSwiftlyVersion: latestVersion) {
                let updatedVersion = try await SelfUpdate.execute(SwiftlyTests.ctx, verbose: true, version: nil)
                #expect(latestVersion == updatedVersion)
            }
        }
    }

    @Test func selfUpdate() async throws {
        try await self.runSelfUpdateTest(latestVersion: Self.newPatchVersion)
        try await self.runSelfUpdateTest(latestVersion: Self.newMinorVersion)
        try await self.runSelfUpdateTest(latestVersion: Self.newMajorVersion)
    }

    /// Verify updating the most up-to-date toolchain has no effect.
    @Test func selfUpdateAlreadyUpToDate() async throws {
        try await self.runSelfUpdateTest(latestVersion: SwiftlyCore.version)
    }

    @Test func selfUpdateToUserSpecifiedVersion() async throws {
        try await SwiftlyTests.withTestHome {
            // GIVEN: swiftly is installed, and at the latest published version
            try await SwiftlyTests.withMockedSwiftlyVersion(latestSwiftlyVersion: SwiftlyCore.version) {
                // WHEN: An attempt is made to self-update to an equal version
                var updatedVersion = try await SelfUpdate.execute(SwiftlyTests.ctx, verbose: true, version: SwiftlyCore.version)
                // THEN: There is no change to the swiftly version
                #expect(updatedVersion == SwiftlyCore.version)

                // WHEN: An attempt is made to self-update to an older version
                updatedVersion = try await SelfUpdate.execute(SwiftlyTests.ctx, verbose: true, version: SwiftlyVersion(major: SwiftlyCore.version.major - 1, minor: 0, patch: 0))
                // THEN: There is no change to the swiftly version
                #expect(updatedVersion == SwiftlyCore.version)

                // WHEN: An attempt is made to self-update to a newer development version
                updatedVersion = try await SelfUpdate.execute(SwiftlyTests.ctx, verbose: true, version: Self.newDevVersion)
                // THEN: swiftly is updated to the new version
                #expect(updatedVersion == Self.newDevVersion)
            }
        }
    }

    /// Verify that validateSwiftly does not call getCurrentSwiftlyRelease when checkForUpdates is false,
    /// and does call it when checkForUpdates is true.
    @Test func validateSwiftlyRespectsCheckForUpdatesFlag() async throws {
        try await SwiftlyTests.withTestHome {
            let tracker = UpdateCheckTracker()
            let ctx = SwiftlyCoreContext(
                mockedHomeDir: SwiftlyTests.ctx.mockedHomeDir,
                httpRequestExecutor: tracker,
                outputHandler: SwiftlyTests.ctx.outputHandler,
                inputProvider: SwiftlyTests.ctx.inputProvider
            )

            var command = SelfUpdate()

            // WHEN: validateSwiftly is called with checkForUpdates: false (as SelfUpdate.run does)
            _ = try await command.validateSwiftly(ctx, checkForUpdates: false)

            // THEN: the swiftly release endpoint was not called
            #expect(await tracker.updateCheckCount == 0)

            // WHEN: validateSwiftly is called with the default checkForUpdates: true
            _ = try await command.validateSwiftly(ctx)

            // THEN: the swiftly release endpoint was called exactly once
            #expect(await tracker.updateCheckCount == 1)
        }
    }

    /// Verify that self-update does not make a redundant call to getCurrentSwiftlyRelease via validateSwiftly.
    /// Before the fix, validateSwiftly would call getCurrentSwiftlyRelease for every subcommand,
    /// resulting in two calls during self-update (one from validateSwiftly, one from SelfUpdate.execute).
    @Test func selfUpdateChecksForUpdatesExactlyOnce() async throws {
        try await SwiftlyTests.withTestHome {
            let tracker = UpdateCheckTracker()
            let ctx = SwiftlyCoreContext(
                mockedHomeDir: SwiftlyTests.ctx.mockedHomeDir,
                httpRequestExecutor: tracker,
                outputHandler: SwiftlyTests.ctx.outputHandler,
                inputProvider: SwiftlyTests.ctx.inputProvider
            )

            // WHEN: self-update runs (already up to date)
            _ = try await SelfUpdate.execute(ctx, verbose: false, version: nil)

            // THEN: getCurrentSwiftlyRelease was called exactly once (by SelfUpdate.execute, not validateSwiftly)
            #expect(await tracker.updateCheckCount == 1)
        }
    }
}
