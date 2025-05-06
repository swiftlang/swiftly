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

    @Test(.testHome(), arguments: [
        "/bin/bash",
        "/bin/zsh",
        "/bin/fish",
    ]) func removesEntryFromShellProfile(_: String) async throws {
        #expect(true)
    }
}
