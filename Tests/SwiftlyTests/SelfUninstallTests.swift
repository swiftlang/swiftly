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
        var ctx = SwiftlyTests.ctx
        ctx.mockedShell = shell

        try await SwiftlyTests.$ctx.withValue(ctx) {
            // Create a profile file with the source line
            let userHome = SwiftlyTests.ctx.mockedHomeDir!

            let profileHome: FilePath
            if shell.hasSuffix("zsh") {
                profileHome = userHome / ".zprofile"
            } else if shell.hasSuffix("bash") {
                if case let p = userHome / ".bash_profile", try await fs.exists(atPath: p) {
                    profileHome = p
                } else if case let p = userHome / ".bash_login", try await fs.exists(atPath: p) {
                    profileHome = p
                } else {
                    profileHome = userHome / ".profile"
                }
            } else if shell.hasSuffix("fish") {
                if let xdgConfigHome = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"], case let xdgConfigURL = FilePath(xdgConfigHome) {
                    let confDir = xdgConfigURL / "fish/conf.d"
                    try await fs.mkdir(.parents, atPath: confDir)
                    profileHome = confDir / "swiftly.fish"
                } else {
                    let confDir = userHome / ".config/fish/conf.d"
                    try await fs.mkdir(.parents, atPath: confDir)
                    profileHome = confDir / "swiftly.fish"
                }
            } else {
                profileHome = userHome / ".profile"
            }

            let envFile: FilePath
            let sourceLine: String
            if shell.hasSuffix("fish") {
                envFile = Swiftly.currentPlatform.swiftlyHomeDir(ctx) / "env.fish"
                sourceLine = """

                # Added by swiftly
                source "\(envFile)"
                """
            } else {
                envFile = Swiftly.currentPlatform.swiftlyHomeDir(ctx) / "env.sh"
                sourceLine = """

                # Added by swiftly
                . "\(envFile)"
                """
            }

            let shellProfileContents = """
            some other line before
            \(sourceLine)
            some other line after
            """

            try Data(shellProfileContents.utf8).write(to: profileHome)

            // then call swiftly uninstall
            try await SwiftlyTests.runCommand(SelfUninstall.self, ["self-uninstall"])

            var sourceLineRemoved = true
            for p in [".profile", ".zprofile", ".bash_profile", ".bash_login", ".config/fish/conf.d/swiftly.fish"] {
                let profile = SwiftlyTests.ctx.mockedHomeDir! / p
                if try await fs.exists(atPath: profile) {
                    if let profileContents = try? String(contentsOf: profile), profileContents.contains(sourceLine) {
                        // expect only the source line is removed
                        #expect(profileContents == shellProfileContents.replacingOccurrences(of: sourceLine, with: ""))
                        sourceLineRemoved = false
                        break
                    }
                }
            }
            #expect(sourceLineRemoved, "swiftly should be removed from the profile file")
        }
    }
}
