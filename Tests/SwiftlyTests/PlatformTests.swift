import Foundation
@testable import Swiftly
@testable import SwiftlyCore
import SystemPackage
import Testing

@Suite struct PlatformTests {
    func mockToolchainDownload(version: String) async throws -> (FilePath, ToolchainVersion, FilePath) {
        let mockDownloader = MockToolchainDownloader(executables: ["swift"])
        let version = try! ToolchainVersion(parsing: version)
        let ext = Swiftly.currentPlatform.toolchainFileExtension
        let tmpDir = mktemp()
        try! await mkdir(atPath: tmpDir, parents: true)
        let mockedToolchainFile = tmpDir / "swift-\(version).\(ext)"
        let mockedToolchain = try await mockDownloader.makeMockedToolchain(toolchain: version, name: tmpDir.lastComponent!.string)
        try mockedToolchain.write(to: mockedToolchainFile)

        return (mockedToolchainFile, version, tmpDir)
    }

    @Test(.testHome()) func install() async throws {
        // GIVEN: a toolchain has been downloaded
        var (mockedToolchainFile, version, tmpDir) = try await self.mockToolchainDownload(version: "5.7.1")
        var cleanup = [tmpDir]
        defer {
            for dir in cleanup {
                try? FileManager.default.removeItem(atPath: dir)
            }
        }

        // WHEN: the platform installs the toolchain
        try await Swiftly.currentPlatform.install(SwiftlyTests.ctx, from: mockedToolchainFile, version: version, verbose: true)
        // THEN: the toolchain is extracted in the toolchains directory
        var toolchains = try await ls(atPath: Swiftly.currentPlatform.swiftlyToolchainsDir(SwiftlyTests.ctx))
        #expect(1 == toolchains.count)

        // GIVEN: a second toolchain has been downloaded
        (mockedToolchainFile, version, tmpDir) = try await self.mockToolchainDownload(version: "5.8.0")
        cleanup += [tmpDir]
        // WHEN: the platform installs the toolchain
        try await Swiftly.currentPlatform.install(SwiftlyTests.ctx, from: mockedToolchainFile, version: version, verbose: true)
        // THEN: the toolchain is added to the toolchains directory
        toolchains = try await ls(atPath: Swiftly.currentPlatform.swiftlyToolchainsDir(SwiftlyTests.ctx))
        #expect(2 == toolchains.count)

        // GIVEN: an identical toolchain has been downloaded
        (mockedToolchainFile, version, tmpDir) = try await self.mockToolchainDownload(version: "5.8.0")
        cleanup += [tmpDir]
        // WHEN: the platform installs the toolchain
        try await Swiftly.currentPlatform.install(SwiftlyTests.ctx, from: mockedToolchainFile, version: version, verbose: true)
        // THEN: the toolchains directory remains the same
        toolchains = try await ls(atPath: Swiftly.currentPlatform.swiftlyToolchainsDir(SwiftlyTests.ctx))
        #expect(2 == toolchains.count)
    }

    @Test(.testHome()) func uninstall() async throws {
        // GIVEN: toolchains have been downloaded, and installed
        var (mockedToolchainFile, version, tmpDir) = try await self.mockToolchainDownload(version: "5.8.0")
        var cleanup = [tmpDir]
        defer {
            for dir in cleanup {
                try? FileManager.default.removeItem(atPath: dir)
            }
        }
        try await Swiftly.currentPlatform.install(SwiftlyTests.ctx, from: mockedToolchainFile, version: version, verbose: true)
        (mockedToolchainFile, version, tmpDir) = try await self.mockToolchainDownload(version: "5.6.3")
        cleanup += [tmpDir]
        try await Swiftly.currentPlatform.install(SwiftlyTests.ctx, from: mockedToolchainFile, version: version, verbose: true)
        // WHEN: one of the toolchains is uninstalled
        try await Swiftly.currentPlatform.uninstall(SwiftlyTests.ctx, version, verbose: true)
        // THEN: there is only one remaining toolchain installed
        var toolchains = try await ls(atPath: Swiftly.currentPlatform.swiftlyToolchainsDir(SwiftlyTests.ctx))
        #expect(1 == toolchains.count)

        // GIVEN; there is only one toolchain installed
        // WHEN: a non-existent toolchain is uninstalled
        try? await Swiftly.currentPlatform.uninstall(SwiftlyTests.ctx, ToolchainVersion(parsing: "5.9.1"), verbose: true)
        // THEN: there is the one remaining toolchain that is still installed
        toolchains = try await ls(atPath: Swiftly.currentPlatform.swiftlyToolchainsDir(SwiftlyTests.ctx))
        #expect(1 == toolchains.count)

        // GIVEN: there is only one toolchain installed
        // WHEN: the last toolchain is uninstalled
        try await Swiftly.currentPlatform.uninstall(SwiftlyTests.ctx, ToolchainVersion(parsing: "5.8.0"), verbose: true)
        // THEN: there are no toolchains installed
        toolchains = try await ls(atPath: Swiftly.currentPlatform.swiftlyToolchainsDir(SwiftlyTests.ctx))
        #expect(0 == toolchains.count)
    }
}
