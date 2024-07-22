import Foundation
@testable import Swiftly
@testable import SwiftlyCore
import XCTest

final class E2ETests: SwiftlyTests {
    /// Tests that `swiftly install latest` successfully installs the latest stable release of Swift end-to-end.
    ///
    /// This will modify the user's system, but will undo those changes afterwards.
    func testInstallLatest() async throws {
        try await self.rollbackLocalChanges {
            var cmd = try self.parseCommand(Install.self, ["install", "latest"])
            try await cmd.run()

            let config = try Config.load()

            guard !config.installedToolchains.isEmpty else {
                XCTFail("expected to install latest main snapshot toolchain but installed toolchains is empty in the config")
                return
            }

            let installedToolchain = config.installedToolchains.first!

            guard case let .stable(release) = installedToolchain else {
                XCTFail("expected swiftly install latest to insall release toolchain but got \(installedToolchain)")
                return
            }

            // As of writing this, 5.8.0 is the latest stable release. Assert it is at least that new.
            XCTAssertTrue(release >= ToolchainVersion.StableRelease(major: 5, minor: 8, patch: 0))

            try await validateInstalledToolchains([installedToolchain], description: "install latest")
        }
    }
}
