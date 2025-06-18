import AsyncHTTPClient
import Foundation
import NIO
@testable import Swiftly
@testable import SwiftlyCore
import Testing

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
}
