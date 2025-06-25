import Foundation
@testable import Swiftly
@testable import SwiftlyCore
import Testing

@Suite struct UnlinkTests {
    /// Tests that disabling swiftly results in swiftlyBinDir with no symlinks to toolchain binaries in it.
    @Test(.testHomeMockedToolchain()) func testUnlink() async throws {
        try await SwiftlyTests.withTestHome {
            let swiftlyBinDir = Swiftly.currentPlatform.swiftlyBinDir(SwiftlyTests.ctx)
            let swiftlyBinaryPath = swiftlyBinDir / "swiftly"
            try "mockBinary".write(to: swiftlyBinaryPath, atomically: true, encoding: .utf8)

            let proxies = ["swift-build", "swift-test", "swift-run"]
            for proxy in proxies {
                let proxyPath = swiftlyBinDir / proxy
                try await fs.symlink(atPath: proxyPath, linkPath: swiftlyBinaryPath)
            }

            _ = try await SwiftlyTests.runWithMockedIO(Unlink.self, ["unlink"])

            let disabledSwiftlyBinDirContents = try await fs.ls(atPath: swiftlyBinDir)
            #expect(disabledSwiftlyBinDirContents == ["swiftly"])
        }
    }
}
