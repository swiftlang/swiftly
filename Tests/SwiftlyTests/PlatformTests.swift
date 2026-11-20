import Foundation
import Subprocess
@testable import Swiftly
@testable import SwiftlyCore
import SystemPackage
import Testing
#if canImport(Darwin)
import Darwin
#endif

@Suite struct PlatformTests {
    func mockToolchainDownload(version: String) async throws -> (FilePath, ToolchainVersion, FilePath) {
        let mockDownloader = MockToolchainDownloader(executables: ["swift"])
        let version = try! ToolchainVersion(parsing: version)
        let ext = Swiftly.currentPlatform.toolchainFileExtension
        let tmpDir = fs.mktemp()
        try! await fs.mkdir(.parents, atPath: tmpDir)
        let mockedToolchainFile = tmpDir / "swift-\(version).\(ext)"
        let mockedToolchain = try await mockDownloader.makeMockedToolchain(toolchain: version, name: tmpDir.lastComponent!.string)
        try mockedToolchain.write(to: mockedToolchainFile)

        return (mockedToolchainFile, version, tmpDir)
    }

    @Test(.testHome(), .mockedSwiftlyVersion()) func install() async throws {
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
        var toolchains = try await fs.ls(atPath: Swiftly.currentPlatform.swiftlyToolchainsDir(SwiftlyTests.ctx))
        #expect(1 == toolchains.count)

        // GIVEN: a second toolchain has been downloaded
        (mockedToolchainFile, version, tmpDir) = try await self.mockToolchainDownload(version: "5.8.0")
        cleanup += [tmpDir]
        // WHEN: the platform installs the toolchain
        try await Swiftly.currentPlatform.install(SwiftlyTests.ctx, from: mockedToolchainFile, version: version, verbose: true)
        // THEN: the toolchain is added to the toolchains directory
        toolchains = try await fs.ls(atPath: Swiftly.currentPlatform.swiftlyToolchainsDir(SwiftlyTests.ctx))
        #expect(2 == toolchains.count)

        // GIVEN: an identical toolchain has been downloaded
        (mockedToolchainFile, version, tmpDir) = try await self.mockToolchainDownload(version: "5.8.0")
        cleanup += [tmpDir]
        // WHEN: the platform installs the toolchain
        try await Swiftly.currentPlatform.install(SwiftlyTests.ctx, from: mockedToolchainFile, version: version, verbose: true)
        // THEN: the toolchains directory remains the same
        toolchains = try await fs.ls(atPath: Swiftly.currentPlatform.swiftlyToolchainsDir(SwiftlyTests.ctx))
        #expect(2 == toolchains.count)
    }

    @Test(.testHome(), .mockedSwiftlyVersion()) func uninstall() async throws {
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
        var toolchains = try await fs.ls(atPath: Swiftly.currentPlatform.swiftlyToolchainsDir(SwiftlyTests.ctx))
        #expect(1 == toolchains.count)

        // GIVEN; there is only one toolchain installed
        // WHEN: a non-existent toolchain is uninstalled
        try? await Swiftly.currentPlatform.uninstall(SwiftlyTests.ctx, ToolchainVersion(parsing: "5.9.1"), verbose: true)
        // THEN: there is the one remaining toolchain that is still installed
        toolchains = try await fs.ls(atPath: Swiftly.currentPlatform.swiftlyToolchainsDir(SwiftlyTests.ctx))
        #expect(1 == toolchains.count)

        // GIVEN: there is only one toolchain installed
        // WHEN: the last toolchain is uninstalled
        try await Swiftly.currentPlatform.uninstall(SwiftlyTests.ctx, ToolchainVersion(parsing: "5.8.0"), verbose: true)
        // THEN: there are no toolchains installed
        toolchains = try await fs.ls(atPath: Swiftly.currentPlatform.swiftlyToolchainsDir(SwiftlyTests.ctx))
        #expect(0 == toolchains.count)
    }

#if os(macOS)
    @Test(.mockedSwiftlyVersion(), .testHome()) func findXcodeToolchainLocation() async throws {
        // GIVEN: the xcode toolchain
        // AND there is xcode installed
        guard let swiftLocation = try? await run(.name("xcrun"), arguments: ["-f", "swift"], output: .string(limit: 1024 * 10)).standardOutput, swiftLocation != "" else {
            return
        }

        // WHEN: the location of the xcode toolchain can be found
        let toolchainLocation = try await Swiftly.currentPlatform.findToolchainLocation(SwiftlyTests.ctx, .xcodeVersion)

        // THEN: the xcode toolchain matches the currently selected xcode toolchain
        #expect(toolchainLocation.string == swiftLocation.replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: "/usr/bin/swift", with: ""))
    }
#endif
}
