import Foundation
@testable import Swiftly
@testable import SwiftlyCore
import Testing

@Suite struct LinkTests {
    /// Tests that enabling swiftly results in swiftlyBinDir being populated with symlinks.
    @Test(.testHomeMockedToolchain()) func testLink() async throws {
        try await SwiftlyTests.withTestHome {
            let swiftlyBinDir = Swiftly.currentPlatform.swiftlyBinDir(SwiftlyTests.ctx)
            let swiftlyBinaryPath = swiftlyBinDir / "swiftly"
            let swiftVersionFilename = SwiftlyTests.ctx.currentDirectory / ".swift-version"

            // Configure a mock toolchain
            let versionString = "6.0.3"
            let toolchainVersion = try ToolchainVersion(parsing: versionString)
            try versionString.write(to: swiftVersionFilename, atomically: true, encoding: .utf8)

            // And start creating a mock folder structure for that toolchain.
            try "swiftly binary".write(to: swiftlyBinaryPath, atomically: true, encoding: .utf8)

            let toolchainDir = Swiftly.currentPlatform.findToolchainLocation(SwiftlyTests.ctx, toolchainVersion) / "usr" / "bin"
            try await fs.mkdir(.parents, atPath: toolchainDir)

            let proxies = ["swift-build", "swift-test", "swift-run"]
            for proxy in proxies {
                let proxyPath = toolchainDir / proxy
                try await fs.symlink(atPath: proxyPath, linkPath: swiftlyBinaryPath)
            }

            _ = try await SwiftlyTests.runWithMockedIO(Link.self, ["link"])

            let enabledSwiftlyBinDirContents = try await fs.ls(atPath: swiftlyBinDir).sorted()
            let expectedProxies = (["swiftly"] + proxies).sorted()
            #expect(enabledSwiftlyBinDirContents == expectedProxies)
        }
    }
}
