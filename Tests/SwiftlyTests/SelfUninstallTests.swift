import Foundation
@testable import Swiftly
@testable import SwiftlyCore
import SystemPackage
import Testing

@Suite struct SelfUninstallTests {
    // Test that swiftly uninstall successfully removes the swiftly binary and the bin directory
    @Test(.mockedSwiftlyVersion()) func removesHomeAndBinDir() async throws {
        try await SwiftlyTests.withTestHome {
            let swiftlyBinDir = Swiftly.currentPlatform.swiftlyBinDir(SwiftlyTests.ctx)
            let swiftlyHomeDir = Swiftly.currentPlatform.swiftlyHomeDir(SwiftlyTests.ctx)
            #expect(
                try await fs.exists(atPath: swiftlyBinDir) == true,
                "swiftly bin directory should exist"
            )
            #expect(
                try await fs.exists(atPath: swiftlyHomeDir) == true,
                "swiftly home directory should exist"
            )

            try await SwiftlyTests.runCommand(SelfUninstall.self, ["self-uninstall"])

            #expect(
                try await fs.exists(atPath: swiftlyBinDir) == false,
                "swiftly bin directory should be removed"
            )
            #expect(
                try await fs.exists(atPath: swiftlyHomeDir) == false,
                "swiftly home directory should be removed"
            )
        }
    }

    @Test(.mockedSwiftlyVersion(), .testHome(), arguments: [
        "/bin/bash",
        "/bin/zsh",
        "/bin/fish",
    ]) func removesEntryFromShellProfile(_ shell: String) async throws {
        // Fresh user without swiftly installed
        try? await fs.remove(atPath: Swiftly.currentPlatform.swiftlyConfigFile(SwiftlyTests.ctx))

        var ctx = SwiftlyTests.ctx
        ctx.mockedShell = shell

        try await SwiftlyTests.$ctx.withValue(ctx) {
            try await SwiftlyTests.runCommand(Init.self, ["init", "--assume-yes", "--skip-install"])

            let fishSourceLine = """
            # Added by swiftly

            source "\(Swiftly.currentPlatform.swiftlyHomeDir(SwiftlyTests.ctx) / "env.fish")"
            """

            let shSourceLine = """
            # Added by swiftly

            . "\(Swiftly.currentPlatform.swiftlyHomeDir(SwiftlyTests.ctx) / "env.sh")"
            """

            // add a few random lines to the profile file(s), both before and after the source line
            for p in [".profile", ".zprofile", ".bash_profile", ".bash_login", ".config/fish/conf.d/swiftly.fish"] {
                let profile = SwiftlyTests.ctx.mockedHomeDir! / p
                if try await fs.exists(atPath: profile) {
                    if let profileContents = try? String(contentsOf: profile) {
                        let newContents = "# Random line before swiftly source\n" +
                            profileContents +
                            "\n# Random line after swiftly source"
                        try Data(newContents.utf8).write(to: profile, options: [.atomic])
                    }
                }
            }

            try await SwiftlyTests.runCommand(SelfUninstall.self, ["self-uninstall", "--assume-yes"])

            for p in [".profile", ".zprofile", ".bash_profile", ".bash_login", ".config/fish/conf.d/swiftly.fish"] {
                let profile = SwiftlyTests.ctx.mockedHomeDir! / p
                if try await fs.exists(atPath: profile) {
                    if let profileContents = try? String(contentsOf: profile) {
                        // check that the source line is removed
                        let isFishProfile = profile.extension == "fish"
                        let sourceLine = isFishProfile ? fishSourceLine : shSourceLine
                        #expect(
                            !profileContents.contains(sourceLine),
                            "swiftly source line should be removed from \(profile.string)"
                        )
                    }
                }
            }
        }
    }
}
