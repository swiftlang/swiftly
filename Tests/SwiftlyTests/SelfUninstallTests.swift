import Foundation
import Testing
@testable import Swiftly
@testable import SwiftlyCore

@Suite struct SelfUninstallTests {
    // Test that swiftly uninstall successfully removes the swiftly binary and the bin directory
    @Test(.mockedSwiftlyVersion()) func uninstall() async throws {
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
}