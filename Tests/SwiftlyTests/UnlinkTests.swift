import Foundation
@testable import Swiftly
@testable import SwiftlyCore
import Testing

@Suite struct UnlinkTests {
    /// Tests that disabling swiftly results in swiftlyBinDir with no symlinks to toolchain binaries in it.
    @Test func testUnlink() async throws {
    try await SwiftlyTests.withTestHome {
            let fm = FileManager.default
            let swiftlyBinDir = Swiftly.currentPlatform.swiftlyBinDir(SwiftlyTests.ctx)
            let swiftlyBinaryPath = swiftlyBinDir.appendingPathComponent("swiftly")
            try "mockBinary".write(to: swiftlyBinaryPath, atomically: true, encoding: .utf8)

            let proxies = ["swift-build", "swift-test", "swift-run"]
            for proxy in proxies {
                let proxyPath = swiftlyBinDir.appendingPathComponent(proxy)
                try fm.createSymbolicLink(at: proxyPath, withDestinationURL: swiftlyBinaryPath)
            }

            _ = try await SwiftlyTests.runWithMockedIO(Unlink.self, ["unlink"])

            let disabledSwiftlyBinDirContents = try fm.contentsOfDirectory(atPath: swiftlyBinDir.path)
            #expect(disabledSwiftlyBinDirContents == ["swiftly"])
        }
    }
}