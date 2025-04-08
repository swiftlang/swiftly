import Foundation
@testable import Swiftly
@testable import SwiftlyCore
import Testing

@Suite struct PlatformTests {
    func mockToolchainDownload(version: String) async throws -> (URL, ToolchainVersion, URL) {
        let mockDownloader = MockToolchainDownloader(executables: ["swift"])
        let version = try! ToolchainVersion(parsing: version)
        let ext = Swiftly.currentPlatform.toolchainFileExtension
        let tmpDir = Swiftly.currentPlatform.getTempFilePath()
        try! FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        let mockedToolchainFile = tmpDir.appendingPathComponent("swift-\(version).\(ext)")
        let mockedToolchain = try mockDownloader.makeMockedToolchain(toolchain: version, name: tmpDir.path)
        try mockedToolchain.write(to: mockedToolchainFile)

        return (mockedToolchainFile, version, tmpDir)
    }

    @Test(.testHome()) func install() async throws {
        // GIVEN: a toolchain has been downloaded
        var (mockedToolchainFile, version, tmpDir) = try await self.mockToolchainDownload(version: "5.7.1")
        var cleanup = [tmpDir]
        defer {
            for dir in cleanup {
                try? FileManager.default.removeItem(at: dir)
            }
        }

        // WHEN: the platform installs the toolchain
        try Swiftly.currentPlatform.install(SwiftlyTests.ctx, from: mockedToolchainFile, version: version, verbose: true)
        // THEN: the toolchain is extracted in the toolchains directory
        var toolchains = try FileManager.default.contentsOfDirectory(at: Swiftly.currentPlatform.swiftlyToolchainsDir(SwiftlyTests.ctx), includingPropertiesForKeys: nil)
        #expect(1 == toolchains.count)

        // GIVEN: a second toolchain has been downloaded
        (mockedToolchainFile, version, tmpDir) = try await self.mockToolchainDownload(version: "5.8.0")
        cleanup += [tmpDir]
        // WHEN: the platform installs the toolchain
        try Swiftly.currentPlatform.install(SwiftlyTests.ctx, from: mockedToolchainFile, version: version, verbose: true)
        // THEN: the toolchain is added to the toolchains directory
        toolchains = try FileManager.default.contentsOfDirectory(at: Swiftly.currentPlatform.swiftlyToolchainsDir(SwiftlyTests.ctx), includingPropertiesForKeys: nil)
        #expect(2 == toolchains.count)

        // GIVEN: an identical toolchain has been downloaded
        (mockedToolchainFile, version, tmpDir) = try await self.mockToolchainDownload(version: "5.8.0")
        cleanup += [tmpDir]
        // WHEN: the platform installs the toolchain
        try Swiftly.currentPlatform.install(SwiftlyTests.ctx, from: mockedToolchainFile, version: version, verbose: true)
        // THEN: the toolchains directory remains the same
        toolchains = try FileManager.default.contentsOfDirectory(at: Swiftly.currentPlatform.swiftlyToolchainsDir(SwiftlyTests.ctx), includingPropertiesForKeys: nil)
        #expect(2 == toolchains.count)
    }

    @Test(.testHome()) func uninstall() async throws {
        // GIVEN: toolchains have been downloaded, and installed
        var (mockedToolchainFile, version, tmpDir) = try await self.mockToolchainDownload(version: "5.8.0")
        var cleanup = [tmpDir]
        defer {
            for dir in cleanup {
                try? FileManager.default.removeItem(at: dir)
            }
        }
        try Swiftly.currentPlatform.install(SwiftlyTests.ctx, from: mockedToolchainFile, version: version, verbose: true)
        (mockedToolchainFile, version, tmpDir) = try await self.mockToolchainDownload(version: "5.6.3")
        cleanup += [tmpDir]
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

#if os(macOS) || os(Linux)
    @Test(
        .mockHomeToolchains(),
        arguments: [
            "/a/b/c:SWIFTLY_BIN_DIR:/d/e/f",
            "SWIFTLY_BIN_DIR:/abcde",
            "/defgh:SWIFTLY_BIN_DIR",
            "/xyzabc:/1/3/4",
            "",
        ]
    ) func proxyEnv(_ path: String) async throws {
        // GIVEN: a PATH that may contain the swiftly bin directory
        let env = ["PATH": path.replacing("SWIFTLY_BIN_DIR", with: Swiftly.currentPlatform.swiftlyBinDir(SwiftlyTests.ctx).path)]

        // WHEN: proxying to an installed toolchain
        let newEnv = try Swiftly.currentPlatform.proxyEnv(SwiftlyTests.ctx, env: env, toolchain: .newStable)

        // THEN: the toolchain's bin directory is added to the beginning of the PATH
        #expect(newEnv["PATH"]!.hasPrefix(Swiftly.currentPlatform.findToolchainLocation(SwiftlyTests.ctx, .newStable).appendingPathComponent("usr/bin").path))

        // AND: the swiftly bin directory is removed from the PATH
        #expect(!newEnv["PATH"]!.contains(Swiftly.currentPlatform.swiftlyBinDir(SwiftlyTests.ctx).path))
        #expect(!newEnv["PATH"]!.contains(Swiftly.currentPlatform.swiftlyBinDir(SwiftlyTests.ctx).path))
    }
#endif
}
