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
            try Swiftly.currentPlatform.uninstall(version)
            // THEN: there is only one remaining toolchain installed
            var toolchains = try FileManager.default.contentsOfDirectory(at: Swiftly.currentPlatform.swiftlyToolchainsDir, includingPropertiesForKeys: nil)
            XCTAssertEqual(1, toolchains.count)

            // GIVEN; there is only one toolchain installed
            // WHEN: a non-existent toolchain is uninstalled
            try? Swiftly.currentPlatform.uninstall(ToolchainVersion(parsing: "5.9.1"))
            // THEN: there is the one remaining toolchain that is still installed
            toolchains = try FileManager.default.contentsOfDirectory(at: Swiftly.currentPlatform.swiftlyToolchainsDir, includingPropertiesForKeys: nil)
            XCTAssertEqual(1, toolchains.count)

            // GIVEN: there is only one toolchain installed
            // WHEN: the last toolchain is uninstalled
            try Swiftly.currentPlatform.uninstall(ToolchainVersion(parsing: "5.8.0"))
            // THEN: there are no toolchains installed
            toolchains = try FileManager.default.contentsOfDirectory(at: Swiftly.currentPlatform.swiftlyToolchainsDir, includingPropertiesForKeys: nil)
            XCTAssertEqual(0, toolchains.count)
        }
    }
}
