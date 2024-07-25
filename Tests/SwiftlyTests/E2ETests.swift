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

            var initCmd = try self.parseCommand(Init.self, ["init", "--assume-yes", "--no-modify-profile"])
            try await initCmd.run()

            var config = try Config.load()

            // Config now exists and is the correct version
            XCTAssertEqual(SwiftlyCore.version, config.version)

            // Check the environment script, if the shell is supported
            let envScript: URL?
            if shell.hasSuffix("bash") || shell.hasSuffix("zsh") {
                envScript = Swiftly.currentPlatform.swiftlyHomeDir.appendingPathComponent("env.sh")
            } else if shell.hasSuffix("fish") {
                envScript = Swiftly.currentPlatform.swiftlyHomeDir.appendingPathComponent("env.fish")
            } else {
                envScript = nil
            }

            if let envScript = envScript {
                XCTAssertTrue(envScript.fileExists())
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

            if let envScript = envScript {
                let whichCmd = if shell.hasSuffix("bash") {
                    "type -P swift"
                } else {
                    "which swift"
                }

                // Check that within a new shell, the swift version succeeds and is the version we expect
                let whichSwift = (try? await Swiftly.currentPlatform.runProgramOutput(shell, "-c", ". \(envScript.path) ; \(whichCmd)")) ?? ""
                XCTAssertTrue(whichSwift.hasPrefix(Swiftly.currentPlatform.swiftlyBinDir.path))
            }
        }
    }
}
