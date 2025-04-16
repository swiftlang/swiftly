import Foundation
@testable import Swiftly
@testable import SwiftlyCore
import XCTest

final class PlatformTests: SwiftlyTests {
    func mockToolchainDownload(version: String) async throws -> (URL, ToolchainVersion) {
        let mockDownloader = MockToolchainDownloader(executables: ["swift"], delegate: SwiftlyCore.httpRequestExecutor)
        let version = try! ToolchainVersion(parsing: version)
        let ext = Swiftly.currentPlatform.toolchainFileExtension
        let tmpDir = Swiftly.currentPlatform.getTempFilePath()
        try! FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        let mockedToolchainFile = tmpDir.appendingPathComponent("swift-\(version).\(ext)")
        let mockedToolchain = try mockDownloader.makeMockedToolchain(toolchain: version, name: tmpDir.path)
        try mockedToolchain.write(to: mockedToolchainFile)

        return (mockedToolchainFile, version)
    }

    func testInstall() async throws {
        try await self.rollbackLocalChanges {
            // GIVEN: a toolchain has been downloaded
            var (mockedToolchainFile, version) = try await self.mockToolchainDownload(version: "5.7.1")
            // WHEN: the platform installs the toolchain
            try Swiftly.currentPlatform.install(from: mockedToolchainFile, version: version, verbose: true)
            // THEN: the toolchain is extracted in the toolchains directory
            var toolchains = try FileManager.default.contentsOfDirectory(at: Swiftly.currentPlatform.swiftlyToolchainsDir, includingPropertiesForKeys: nil)
            XCTAssertEqual(1, toolchains.count)

            // GIVEN: a second toolchain has been downloaded
            (mockedToolchainFile, version) = try await self.mockToolchainDownload(version: "5.8.0")
            // WHEN: the platform installs the toolchain
            try Swiftly.currentPlatform.install(from: mockedToolchainFile, version: version, verbose: true)
            // THEN: the toolchain is added to the toolchains directory
            toolchains = try FileManager.default.contentsOfDirectory(at: Swiftly.currentPlatform.swiftlyToolchainsDir, includingPropertiesForKeys: nil)
            XCTAssertEqual(2, toolchains.count)

            // GIVEN: an identical toolchain has been downloaded
            (mockedToolchainFile, version) = try await self.mockToolchainDownload(version: "5.8.0")
            // WHEN: the platform installs the toolchain
            try Swiftly.currentPlatform.install(from: mockedToolchainFile, version: version, verbose: true)
            // THEN: the toolchains directory remains the same
            toolchains = try FileManager.default.contentsOfDirectory(at: Swiftly.currentPlatform.swiftlyToolchainsDir, includingPropertiesForKeys: nil)
            XCTAssertEqual(2, toolchains.count)
        }
    }

    func testUninstall() async throws {
        try await self.rollbackLocalChanges {
            // GIVEN: toolchains have been downloaded, and installed
            var (mockedToolchainFile, version) = try await self.mockToolchainDownload(version: "5.8.0")
            try Swiftly.currentPlatform.install(from: mockedToolchainFile, version: version, verbose: true)
            (mockedToolchainFile, version) = try await self.mockToolchainDownload(version: "5.6.3")
            try Swiftly.currentPlatform.install(from: mockedToolchainFile, version: version, verbose: true)
            // WHEN: one of the toolchains is uninstalled
            try Swiftly.currentPlatform.uninstall(version, verbose: true)
            // THEN: there is only one remaining toolchain installed
            var toolchains = try FileManager.default.contentsOfDirectory(at: Swiftly.currentPlatform.swiftlyToolchainsDir, includingPropertiesForKeys: nil)
            XCTAssertEqual(1, toolchains.count)

            // GIVEN; there is only one toolchain installed
            // WHEN: a non-existent toolchain is uninstalled
            try? Swiftly.currentPlatform.uninstall(ToolchainVersion(parsing: "5.9.1"), verbose: true)
            // THEN: there is the one remaining toolchain that is still installed
            toolchains = try FileManager.default.contentsOfDirectory(at: Swiftly.currentPlatform.swiftlyToolchainsDir, includingPropertiesForKeys: nil)
            XCTAssertEqual(1, toolchains.count)

            // GIVEN: there is only one toolchain installed
            // WHEN: the last toolchain is uninstalled
            try Swiftly.currentPlatform.uninstall(ToolchainVersion(parsing: "5.8.0"), verbose: true)
            // THEN: there are no toolchains installed
            toolchains = try FileManager.default.contentsOfDirectory(at: Swiftly.currentPlatform.swiftlyToolchainsDir, includingPropertiesForKeys: nil)
            XCTAssertEqual(0, toolchains.count)
        }
    }

#if os(macOS) || os(Linux)
    func testProxyEnv() async throws {
        try await self.rollbackLocalChanges {
            var (mockedToolchainFile, version) = try await self.mockToolchainDownload(version: SwiftlyTests.newStable.name)
            try Swiftly.currentPlatform.install(from: mockedToolchainFile, version: version, verbose: true)

            for path in [
                "/a/b/c:SWIFTLY_BIN_DIR:/d/e/f",
                "SWIFTLY_BIN_DIR:/abcde",
                "/defgh:SWIFTLY_BIN_DIR",
                "/xyzabc:/1/3/4",
                "",
            ] {
                // GIVEN: a PATH that may contain the swiftly bin directory
                let env = ["PATH": path.replacing("SWIFTLY_BIN_DIR", with: Swiftly.currentPlatform.swiftlyBinDir.path)]

                // WHEN: proxying to an installed toolchain
                let newEnv = try Swiftly.currentPlatform.proxyEnv(env: env, toolchain: SwiftlyTests.newStable)

                // THEN: the toolchain's bin directory is added to the beginning of the PATH
                XCTAssert(newEnv["PATH"]!.hasPrefix(Swiftly.currentPlatform.findToolchainLocation(SwiftlyTests.newStable).appendingPathComponent("usr/bin").path))

                // AND: the swiftly bin directory is removed from the PATH
                XCTAssert(!newEnv["PATH"]!.contains(Swiftly.currentPlatform.swiftlyBinDir.path))
                XCTAssert(!newEnv["PATH"]!.contains(Swiftly.currentPlatform.swiftlyBinDir.path))
            }
        }
    }
#endif
}
