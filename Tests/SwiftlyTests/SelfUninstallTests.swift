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

    // @Test(.mockedSwiftlyVersion(), .testHome(), arguments: [
    //     "/bin/bash",
    //     "/bin/zsh",
    //     "/bin/fish",
    // ]) func removesEntryFromShell(_ shell: String) async throws {
    //     var ctx = SwiftlyTests.ctx
    //     ctx.mockedShell = shell

    //     try await SwiftlyTests.$ctx.withValue(ctx) {
    //         let envScript: FilePath?
    //         if shell.hasSuffix("bash") || shell.hasSuffix("zsh") {
    //             envScript = Swiftly.currentPlatform.swiftlyHomeDir(SwiftlyTests.ctx) / "env.sh"
    //         } else if shell.hasSuffix("fish") {
    //             envScript = Swiftly.currentPlatform.swiftlyHomeDir(SwiftlyTests.ctx) / "env.fish"
    //         } else {
    //             envScript = nil
    //         }

    //         // if let envScript {
    //         //     print(envScript.string)
    //         // }

    //         // WHEN: swiftly is invoked to uninstall
    //         try await SwiftlyTests.runCommand(SelfUninstall.self, ["self-uninstall"])

    //         // AND: it removes the source line from the user profile
    //             // var sourceLineExist = false
    //             for p in [
    //                 ".profile",
    //                 ".zprofile",
    //                 ".bash_profile",
    //                 ".bash_login",
    //                 ".config/fish/conf.d/swiftly.fish",
    //             ] {
    //                 let profile = SwiftlyTests.ctx.mockedHomeDir! / p
    //                 if try await fs.exists(atPath: profile) {
    //                     // print profile contents only
    //                     if let profileContents = try? String(contentsOf: profile) {
    //                         print("contents of profile \(profileContents)")
    //                         // sourceLineExist = profileContents.contains(envScript.string)
    //                     }

    //                 }
    //             }
    //             // #expect(sourceLineExist == false, "source line should be removed from the profile")
    //     }
    // }
}
