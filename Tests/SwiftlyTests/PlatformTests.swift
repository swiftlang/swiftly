import Foundation
@testable import Swiftly
@testable import SwiftlyCore
import Testing

@Suite struct PlatformTests {
    func mockToolchainDownload(version: String) async throws -> (URL, ToolchainVersion) {
        let mockDownloader = MockToolchainDownloader(executables: ["swift"])
        let version = try! ToolchainVersion(parsing: version)
        let ext = Swiftly.currentPlatform.toolchainFileExtension
        let tmpDir = Swiftly.currentPlatform.getTempFilePath()
        try! FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        let mockedToolchainFile = tmpDir.appendingPathComponent("swift-\(version).\(ext)")
        let mockedToolchain = try mockDownloader.makeMockedToolchain(toolchain: version, name: tmpDir.path)
        try mockedToolchain.write(to: mockedToolchainFile)

        return (mockedToolchainFile, version)
    }

    @Test(.testHome()) func install() async throws {
        // GIVEN: a toolchain has been downloaded
        var (mockedToolchainFile, version) = try await self.mockToolchainDownload(version: "5.7.1")
        // WHEN: the platform installs the toolchain
        try Swiftly.currentPlatform.install(SwiftlyTests.ctx, from: mockedToolchainFile, version: version, verbose: true)
        // THEN: the toolchain is extracted in the toolchains directory
        var toolchains = try FileManager.default.contentsOfDirectory(at: Swiftly.currentPlatform.swiftlyToolchainsDir(SwiftlyTests.ctx), includingPropertiesForKeys: nil)
        #expect(1 == toolchains.count)

        // GIVEN: a second toolchain has been downloaded
        (mockedToolchainFile, version) = try await self.mockToolchainDownload(version: "5.8.0")
        // WHEN: the platform installs the toolchain
        try Swiftly.currentPlatform.install(SwiftlyTests.ctx, from: mockedToolchainFile, version: version, verbose: true)
        // THEN: the toolchain is added to the toolchains directory
        toolchains = try FileManager.default.contentsOfDirectory(at: Swiftly.currentPlatform.swiftlyToolchainsDir(SwiftlyTests.ctx), includingPropertiesForKeys: nil)
        #expect(2 == toolchains.count)

        // GIVEN: an identical toolchain has been downloaded
        (mockedToolchainFile, version) = try await self.mockToolchainDownload(version: "5.8.0")
        // WHEN: the platform installs the toolchain
        try Swiftly.currentPlatform.install(SwiftlyTests.ctx, from: mockedToolchainFile, version: version, verbose: true)
        // THEN: the toolchains directory remains the same
        toolchains = try FileManager.default.contentsOfDirectory(at: Swiftly.currentPlatform.swiftlyToolchainsDir(SwiftlyTests.ctx), includingPropertiesForKeys: nil)
        #expect(2 == toolchains.count)
    }

    @Test(.testHome()) func uninstall() async throws {
        // GIVEN: toolchains have been downloaded, and installed
        var (mockedToolchainFile, version) = try await self.mockToolchainDownload(version: "5.8.0")
        try Swiftly.currentPlatform.install(SwiftlyTests.ctx, from: mockedToolchainFile, version: version, verbose: true)
        (mockedToolchainFile, version) = try await self.mockToolchainDownload(version: "5.6.3")
        try Swiftly.currentPlatform.install(SwiftlyTests.ctx, from: mockedToolchainFile, version: version, verbose: true)
        // WHEN: one of the toolchains is uninstalled
        try Swiftly.currentPlatform.uninstall(SwiftlyTests.ctx, version, verbose: true)
        // THEN: there is only one remaining toolchain installed
        var toolchains = try FileManager.default.contentsOfDirectory(at: Swiftly.currentPlatform.swiftlyToolchainsDir(SwiftlyTests.ctx), includingPropertiesForKeys: nil)
        #expect(1 == toolchains.count)

        // GIVEN; there is only one toolchain installed
        // WHEN: a non-existent toolchain is uninstalled
        try? Swiftly.currentPlatform.uninstall(SwiftlyTests.ctx, ToolchainVersion(parsing: "5.9.1"), verbose: true)
        // THEN: there is the one remaining toolchain that is still installed
        toolchains = try FileManager.default.contentsOfDirectory(at: Swiftly.currentPlatform.swiftlyToolchainsDir(SwiftlyTests.ctx), includingPropertiesForKeys: nil)
        #expect(1 == toolchains.count)

        // GIVEN: there is only one toolchain installed
        // WHEN: the last toolchain is uninstalled
        try Swiftly.currentPlatform.uninstall(SwiftlyTests.ctx, ToolchainVersion(parsing: "5.8.0"), verbose: true)
        // THEN: there are no toolchains installed
        toolchains = try FileManager.default.contentsOfDirectory(at: Swiftly.currentPlatform.swiftlyToolchainsDir(SwiftlyTests.ctx), includingPropertiesForKeys: nil)
        #expect(0 == toolchains.count)
    }
}
