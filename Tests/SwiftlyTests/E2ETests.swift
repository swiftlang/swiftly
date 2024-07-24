import Foundation
@testable import Swiftly
@testable import SwiftlyCore
import XCTest

final class E2ETests: SwiftlyTests {
    /// Tests that `swiftly init` and `swiftly install latest` successfully installs the latest stable release.
    ///
    /// This will modify the user's system, but will undo those changes afterwards.
    func testInstallLatest() async throws {
        try await self.rollbackLocalChanges {
            // Clear out the config.json to proceed with the init
            try? FileManager.default.removeItem(at: Swiftly.currentPlatform.swiftlyConfigFile)

            let shell = if let s = ProcessInfo.processInfo.environment["SHELL"] {
                s
            } else {
                try await Swiftly.currentPlatform.getShell()
            }

            // Check that no swift toolchain is available in this environment yet, not macOS though where
            //  there's always a swift installed
#if !os(macOS)
            XCTAssertThrowsError(try Swiftly.currentPlatform.runProgram(shell, "-c", "swift --version"))
#endif

            var initCmd = try self.parseCommand(Init.self, ["init", "--assume-yes"])
            try await initCmd.run()

            var config = try Config.load()

            // Config now exists and is the correct version
            XCTAssertEqual(SwiftlyCore.version, config.version)

            if shell.hasSuffix("bash") || shell.hasSuffix("zsh") {
                XCTAssertTrue(Swiftly.currentPlatform.swiftlyHomeDir.appendingPathComponent("env.sh").fileExists())
            } else if shell.hasSuffix("fish") {
                XCTAssertTrue(Swiftly.currentPlatform.swiftlyHomeDir.appendingPathComponent("env.fish").fileExists())
            }

            var cmd = try self.parseCommand(Install.self, ["install", "latest"])
            try await cmd.run()

            config = try Config.load()

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

            // Check that within a new shell, the swift version succeeds and is the version we expect
            let versionOut = try? await Swiftly.currentPlatform.runProgramOutput(shell, "-l", "-c", "swift --version")
            XCTAssertTrue((versionOut ?? "").contains(installedToolchain.name))
        }
    }
}
