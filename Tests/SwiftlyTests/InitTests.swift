import Foundation
@testable import Swiftly
@testable import SwiftlyCore
import Testing

@Suite struct InitTests {
    @Test(.testHome()) func initFresh() async throws {
        // GIVEN: a fresh user account without Swiftly installed
        try? FileManager.default.removeItem(at: Swiftly.currentPlatform.swiftlyConfigFile(SwiftlyTests.ctx))

        // AND: the user is using the bash shell
        let shell = "/bin/bash"
        var ctx = SwiftlyTests.ctx
        ctx.mockedShell = shell

        try await SwiftlyTests.$ctx.withValue(ctx) {
            let envScript: URL?
            if shell.hasSuffix("bash") || shell.hasSuffix("zsh") {
                envScript = Swiftly.currentPlatform.swiftlyHomeDir(SwiftlyTests.ctx).appendingPathComponent("env.sh")
            } else if shell.hasSuffix("fish") {
                envScript = Swiftly.currentPlatform.swiftlyHomeDir(SwiftlyTests.ctx).appendingPathComponent("env.fish")
            } else {
                envScript = nil
            }

            if let envScript {
                #expect(!envScript.fileExists())
            }

            // WHEN: swiftly is invoked to init the user account and finish swiftly installation
            try await SwiftlyTests.runCommand(Init.self, ["init", "--assume-yes", "--skip-install"])

            // THEN: it creates a valid configuration at the correct version
            let config = try Config.load()
            #expect(SwiftlyCore.version == config.version)

            // AND: it creates an environment script suited for the type of shell
            if let envScript {
                #expect(envScript.fileExists())
                if let scriptContents = try? String(contentsOf: envScript) {
                    #expect(scriptContents.contains("SWIFTLY_HOME_DIR"))
                    #expect(scriptContents.contains("SWIFTLY_BIN_DIR"))
                    #expect(scriptContents.contains(Swiftly.currentPlatform.swiftlyHomeDir(SwiftlyTests.ctx).path))
                    #expect(scriptContents.contains(Swiftly.currentPlatform.swiftlyBinDir(SwiftlyTests.ctx).path))
                }
            }

            // AND: it sources the script from the user profile
            if let envScript {
                var foundSourceLine = false
                for p in [".profile", ".zprofile", ".bash_profile", ".bash_login", ".config/fish/conf.d/swiftly.fish"] {
                    let profile = SwiftlyTests.ctx.mockedHomeDir!.appendingPathComponent(p)
                    if profile.fileExists() {
                        if let profileContents = try? String(contentsOf: profile), profileContents.contains(envScript.path) {
                            foundSourceLine = true
                            break
                        }
                    }
                }
                #expect(foundSourceLine)
            }
        }
    }

    @Test(.testHome()) func initOverwrite() async throws {
        // GIVEN: a user account with swiftly already installed
        try? FileManager.default.removeItem(at: Swiftly.currentPlatform.swiftlyConfigFile(SwiftlyTests.ctx))

        try await SwiftlyTests.runCommand(Init.self, ["init", "--assume-yes", "--skip-install"])

        // Add some customizations to files and directories
        var config = try Config.load()
        config.version = try SwiftlyVersion(parsing: "100.0.0")
        try config.save()

        try Data("".utf8).append(to: Swiftly.currentPlatform.swiftlyHomeDir(SwiftlyTests.ctx).appendingPathComponent("foo.txt"))
        try Data("".utf8).append(to: Swiftly.currentPlatform.swiftlyToolchainsDir(SwiftlyTests.ctx).appendingPathComponent("foo.txt"))

        // WHEN: swiftly is initialized with overwrite enabled
        try await SwiftlyTests.runCommand(Init.self, ["init", "--assume-yes", "--skip-install", "--overwrite"])

        // THEN: everything is overwritten in initialization
        config = try Config.load()
        #expect(SwiftlyCore.version == config.version)
        #expect(!Swiftly.currentPlatform.swiftlyHomeDir(SwiftlyTests.ctx).appendingPathComponent("foo.txt").fileExists())
        #expect(!Swiftly.currentPlatform.swiftlyToolchainsDir(SwiftlyTests.ctx).appendingPathComponent("foo.txt").fileExists())
    }

    @Test(.testHome()) func initTwice() async throws {
        // GIVEN: a user account with swiftly already installed
        try? FileManager.default.removeItem(at: Swiftly.currentPlatform.swiftlyConfigFile(SwiftlyTests.ctx))

        try await SwiftlyTests.runCommand(Init.self, ["init", "--assume-yes", "--skip-install"])

        // Add some customizations to files and directories
        var config = try Config.load()
        config.version = try SwiftlyVersion(parsing: "100.0.0")
        try config.save()

        try Data("".utf8).append(to: Swiftly.currentPlatform.swiftlyHomeDir(SwiftlyTests.ctx).appendingPathComponent("foo.txt"))
        try Data("".utf8).append(to: Swiftly.currentPlatform.swiftlyToolchainsDir(SwiftlyTests.ctx).appendingPathComponent("foo.txt"))

        // WHEN: swiftly init is invoked a second time
        var threw = false
        do {
            try await SwiftlyTests.runCommand(Init.self, ["init", "--assume-yes", "--skip-install"])
        } catch {
            threw = true
        }

        // THEN: init fails
        #expect(threw)

        // AND: files were left intact
        config = try Config.load()
        #expect(try SwiftlyVersion(parsing: "100.0.0") == config.version)
        #expect(Swiftly.currentPlatform.swiftlyHomeDir(SwiftlyTests.ctx).appendingPathComponent("foo.txt").fileExists())
        #expect(Swiftly.currentPlatform.swiftlyToolchainsDir(SwiftlyTests.ctx).appendingPathComponent("foo.txt").fileExists())
    }
}
