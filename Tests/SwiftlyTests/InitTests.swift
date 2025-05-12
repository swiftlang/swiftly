import Foundation
@testable import Swiftly
@testable import SwiftlyCore
import XCTest

final class InitTests: SwiftlyTests {
    func testInitFresh() async throws {
        try await self.rollbackLocalChanges {
            // GIVEN: a fresh user account without Swiftly installed
            try? FileManager.default.removeItem(at: Swiftly.currentPlatform.swiftlyConfigFile)
            let shell = if let s = ProcessInfo.processInfo.environment["SHELL"] {
                s
            } else {
                try await Swiftly.currentPlatform.getShell()
            }
            let envScript: URL?
            if shell.hasSuffix("bash") || shell.hasSuffix("zsh") {
                envScript = Swiftly.currentPlatform.swiftlyHomeDir.appendingPathComponent("env.sh")
            } else if shell.hasSuffix("fish") {
                envScript = Swiftly.currentPlatform.swiftlyHomeDir.appendingPathComponent("env.fish")
            } else {
                envScript = nil
            }

            if let envScript = envScript {
                XCTAssertFalse(envScript.fileExists())
            }

            // WHEN: swiftly is invoked to init the user account and finish swiftly installation
            var initCmd = try self.parseCommand(Init.self, ["init", "--assume-yes", "--skip-install"])
            try await initCmd.run()

            // THEN: it creates a valid configuration at the correct version
            let config = try Config.load()
            XCTAssertEqual(SwiftlyCore.version, config.version)

            // AND: it creates an environment script suited for the type of shell
            if let envScript = envScript {
                XCTAssertTrue(envScript.fileExists())
                if let scriptContents = try? String(contentsOf: envScript) {
                    XCTAssertTrue(scriptContents.contains("SWIFTLY_HOME_DIR"))
                    XCTAssertTrue(scriptContents.contains("SWIFTLY_BIN_DIR"))
                    XCTAssertTrue(scriptContents.contains(Swiftly.currentPlatform.swiftlyHomeDir.path))
                    XCTAssertTrue(scriptContents.contains(Swiftly.currentPlatform.swiftlyBinDir.path))
                }
            }

            // AND: it sources the script from the user profile
            if let envScript = envScript {
                var foundSourceLine = false
                for p in [".profile", ".zprofile", ".bash_profile", ".bash_login", ".config/fish/conf.d/swiftly.fish"] {
                    let profile = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(p)
                    if profile.fileExists() {
                        if let profileContents = try? String(contentsOf: profile), profileContents.contains(envScript.path) {
                            foundSourceLine = true
                            break
                        }
                    }
                }
                XCTAssertTrue(foundSourceLine)
            }
        }
    }

    func testInitOverwrite() async throws {
        try await self.rollbackLocalChanges {
            // GIVEN: a user account with swiftly already installed
            try? FileManager.default.removeItem(at: Swiftly.currentPlatform.swiftlyConfigFile)

            var initCmd = try self.parseCommand(Init.self, ["init", "--assume-yes", "--skip-install"])
            try await initCmd.run()

            // Add some customizations to files and directories
            var config = try Config.load()
            config.version = try SwiftlyVersion(parsing: "100.0.0")
            try config.save()

            try Data("".utf8).append(to: Swiftly.currentPlatform.swiftlyHomeDir.appendingPathComponent("foo.txt"))
            try Data("".utf8).append(to: Swiftly.currentPlatform.swiftlyToolchainsDir.appendingPathComponent("foo.txt"))

            // WHEN: swiftly is initialized with overwrite enabled
            initCmd = try self.parseCommand(Init.self, ["init", "--assume-yes", "--skip-install", "--overwrite"])
            try await initCmd.run()

            // THEN: everything is overwritten in initialization
            config = try Config.load()
            XCTAssertEqual(SwiftlyCore.version, config.version)
            XCTAssertFalse(Swiftly.currentPlatform.swiftlyHomeDir.appendingPathComponent("foo.txt").fileExists())
            XCTAssertFalse(Swiftly.currentPlatform.swiftlyToolchainsDir.appendingPathComponent("foo.txt").fileExists())
        }
    }

    func testInitTwice() async throws {
        try await self.rollbackLocalChanges {
            // GIVEN: a user account with swiftly already installed
            try? FileManager.default.removeItem(at: Swiftly.currentPlatform.swiftlyConfigFile)

            var initCmd = try self.parseCommand(Init.self, ["init", "--assume-yes", "--skip-install"])
            try await initCmd.run()

            // Add some customizations to files and directories
            var config = try Config.load()
            config.version = try SwiftlyVersion(parsing: "100.0.0")
            try config.save()

            try Data("".utf8).append(to: Swiftly.currentPlatform.swiftlyHomeDir.appendingPathComponent("foo.txt"))
            try Data("".utf8).append(to: Swiftly.currentPlatform.swiftlyToolchainsDir.appendingPathComponent("foo.txt"))

            // WHEN: swiftly init is invoked a second time
            initCmd = try self.parseCommand(Init.self, ["init", "--assume-yes", "--skip-install"])
            var threw = false
            do {
                try await initCmd.run()
            } catch {
                threw = true
            }

            // THEN: init fails
            XCTAssertTrue(threw)

            // AND: files were left intact
            config = try Config.load()
            XCTAssertEqual(try SwiftlyVersion(parsing: "100.0.0"), config.version)
            XCTAssertTrue(Swiftly.currentPlatform.swiftlyHomeDir.appendingPathComponent("foo.txt").fileExists())
            XCTAssertTrue(Swiftly.currentPlatform.swiftlyToolchainsDir.appendingPathComponent("foo.txt").fileExists())
        }
    }

    func testAllowedInstalledCommands() async throws {
        XCTAssertTrue(try Init.allowedInstallCommands.wholeMatch(in: "apt-get -y install python3 libsqlite3") != nil)
        XCTAssertTrue(try Init.allowedInstallCommands.wholeMatch(in: "yum -y install python3 libsqlite3") != nil)
        XCTAssertTrue(try Init.allowedInstallCommands.wholeMatch(in: "yum -y install python3 libsqlite3-dev") != nil)
        XCTAssertTrue(try Init.allowedInstallCommands.wholeMatch(in: "yum -y install libstdc++-dev:i386") != nil)

        XCTAssertTrue(try Init.allowedInstallCommands.wholeMatch(in: "SOME_ENV_VAR=abcde yum -y install libstdc++-dev:i386") == nil)
        XCTAssertTrue(try Init.allowedInstallCommands.wholeMatch(in: "apt-get -y install libstdc++-dev:i386; rm -rf /") == nil)
        XCTAssertTrue(try Init.allowedInstallCommands.wholeMatch(in: "apt-get -y install libstdc++-dev:i386\nrm -rf /") == nil)
    }
}
