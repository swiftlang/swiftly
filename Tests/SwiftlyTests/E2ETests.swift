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

            var cmd = try self.parseCommand(Install.self, ["install", "latest", "--post-install-file=\(Swiftly.currentPlatform.getTempFilePath().path)"])
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
        }
    }

    func testAutomatedWorkflow() async throws {
        try XCTSkipIf(ProcessInfo.processInfo.environment["SWIFTLY_SYSTEM_MUTATING"] == nil, "Not running test since it mutates the system and SWIFTLY_SYSTEM_MUTATING environment variable is not set. This test should be run in a throw away environment, such as a container.")

        print("Extracting swiftly release")
#if os(Linux)
        try Swiftly.currentPlatform.runProgram("tar", "-zxvf", "swiftly.tar.gz", quiet: false)
#elseif os(macOS)
        try Swiftly.currentPlatform.runProgram("installer", "-pkg", "swiftly.pkg", "-target", "CurrentUserHomeDirectory", quiet: false)
#endif

        print("Running 'swiftly init --assume-yes --verbose' to install swiftly and the latest toolchain")

#if os(Linux)
        let extractedSwiftly = "./swiftly"
#elseif os(macOS)
        let extractedSwiftly = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("usr/local/bin/swiftly").path
#endif

        try Swiftly.currentPlatform.runProgram(extractedSwiftly, "init", "--assume-yes", quiet: false)

        let shell = try await Swiftly.currentPlatform.getShell()

        var env = ProcessInfo.processInfo.environment

        // Setting this environment helps to ensure that the profile gets sourced with bash, even if it is not in an interactive shell
        if shell == "/bin/bash" {
            env["BASH_ENV"] = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".profile").path
        } else if shell == "/bin/fish" {
            env["fish_trace"] = "on"
        }

        try Swiftly.currentPlatform.runProgram(shell, "-v", "-l", "-c", "swiftly install --assume-yes latest --post-install-file=./post-install.sh", env: env)

        if FileManager.default.fileExists(atPath: "./post-install.sh") {
            try Swiftly.currentPlatform.runProgram(shell, "./post-install.sh")
        }

        try Swiftly.currentPlatform.runProgram(shell, "-v", "-l", "-c", "swift --version", quiet: false, env: env)
    }
}
