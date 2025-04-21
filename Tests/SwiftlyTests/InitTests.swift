import Foundation
@testable import Swiftly
@testable import SwiftlyCore
import SystemPackage
import Testing

@Suite struct InitTests {
    @Test(.testHome(), arguments: ["/bin/bash", "/bin/zsh", "/bin/fish"]) func initFresh(_ shell: String) async throws {
        // GIVEN: a fresh user account without swiftly installed
        try? await fs.remove(atPath: Swiftly.currentPlatform.swiftlyConfigFile(SwiftlyTests.ctx))

        // AND: the user is using the bash shell
        var ctx = SwiftlyTests.ctx
        ctx.mockedShell = shell

        try await SwiftlyTests.$ctx.withValue(ctx) {
            let envScript: FilePath?
            if shell.hasSuffix("bash") || shell.hasSuffix("zsh") {
                envScript = Swiftly.currentPlatform.swiftlyHomeDir(SwiftlyTests.ctx) / "env.sh"
            } else if shell.hasSuffix("fish") {
                envScript = Swiftly.currentPlatform.swiftlyHomeDir(SwiftlyTests.ctx) / "env.fish"
            } else {
                envScript = nil
            }

            if let envScript {
                #expect(!(try await fs.exists(atPath: envScript)))
            }

            // WHEN: swiftly is invoked to init the user account and finish swiftly installation
            try await SwiftlyTests.runCommand(Init.self, ["init", "--assume-yes", "--skip-install"])

            // THEN: it creates a valid configuration at the correct version
            let config = try await Config.load()
            #expect(SwiftlyCore.version == config.version)

            // AND: it creates an environment script suited for the type of shell
            if let envScript {
                #expect(try await fs.exists(atPath: envScript))
                if let scriptContents = try? String(contentsOf: envScript) {
                    #expect(scriptContents.contains("SWIFTLY_HOME_DIR"))
                    #expect(scriptContents.contains("SWIFTLY_BIN_DIR"))
                    #expect(scriptContents.contains(Swiftly.currentPlatform.swiftlyHomeDir(SwiftlyTests.ctx).string))
                    #expect(scriptContents.contains(Swiftly.currentPlatform.swiftlyBinDir(SwiftlyTests.ctx).string))
                }
            }

            // AND: it sources the script from the user profile
            if let envScript {
                var foundSourceLine = false
                for p in [".profile", ".zprofile", ".bash_profile", ".bash_login", ".config/fish/conf.d/swiftly.fish"] {
                    let profile = SwiftlyTests.ctx.mockedHomeDir! / p
                    if try await fs.exists(atPath: profile) {
                        if let profileContents = try? String(contentsOf: profile), profileContents.contains(envScript.string) {
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
        try? await fs.remove(atPath: Swiftly.currentPlatform.swiftlyConfigFile(SwiftlyTests.ctx))

        try await SwiftlyTests.runCommand(Init.self, ["init", "--assume-yes", "--skip-install"])

        // Add some customizations to files and directories
        var config = try await Config.load()
        config.version = try SwiftlyVersion(parsing: "100.0.0")
        try config.save()

        try Data("".utf8).append(to: Swiftly.currentPlatform.swiftlyHomeDir(SwiftlyTests.ctx) / "foo.txt")
        try Data("".utf8).append(to: Swiftly.currentPlatform.swiftlyToolchainsDir(SwiftlyTests.ctx) / "foo.txt")

        // WHEN: swiftly is initialized with overwrite enabled
        try await SwiftlyTests.runCommand(Init.self, ["init", "--assume-yes", "--skip-install", "--overwrite"])

        // THEN: everything is overwritten in initialization
        config = try await Config.load()
        #expect(SwiftlyCore.version == config.version)
        #expect(!(try await fs.exists(atPath: Swiftly.currentPlatform.swiftlyHomeDir(SwiftlyTests.ctx) / "foo.txt")))
        #expect(!(try await fs.exists(atPath: Swiftly.currentPlatform.swiftlyToolchainsDir(SwiftlyTests.ctx) / "foo.txt")))
    }

    @Test(.testHome()) func initTwice() async throws {
        // GIVEN: a user account with swiftly already installed
        try? await fs.remove(atPath: Swiftly.currentPlatform.swiftlyConfigFile(SwiftlyTests.ctx))

        try await SwiftlyTests.runCommand(Init.self, ["init", "--assume-yes", "--skip-install"])

        // Add some customizations to files and directories
        var config = try await Config.load()
        config.version = try SwiftlyVersion(parsing: "100.0.0")
        try config.save()

        try Data("".utf8).append(to: Swiftly.currentPlatform.swiftlyHomeDir(SwiftlyTests.ctx) / "foo.txt")
        try Data("".utf8).append(to: Swiftly.currentPlatform.swiftlyToolchainsDir(SwiftlyTests.ctx) / "foo.txt")

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
        config = try await Config.load()
        #expect(try SwiftlyVersion(parsing: "100.0.0") == config.version)
        #expect(try await fs.exists(atPath: Swiftly.currentPlatform.swiftlyHomeDir(SwiftlyTests.ctx) / "foo.txt"))
        #expect(try await fs.exists(atPath: Swiftly.currentPlatform.swiftlyToolchainsDir(SwiftlyTests.ctx) / "foo.txt"))
    }
}
