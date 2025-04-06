import AsyncHTTPClient
import Foundation
@testable import Swiftly
@testable import SwiftlyCore
import Testing

@Suite struct HTTPClientTests {
    @Test func getSwiftOrgGPGKeys() async throws {
        let httpClient = SwiftlyHTTPClient(httpRequestExecutor: HTTPRequestExecutorImpl())

        let tmpFile = FileManager.default.temporaryDirectory.appendingPathComponent("swiftly-\(UUID())")
        _ = FileManager.default.createFile(atPath: tmpFile.path, contents: nil)
        defer {
            try? FileManager.default.removeItem(at: tmpFile)
        }

        let gpgKeysUrl = URL(string: "https://www.swift.org/keys/all-keys.asc")!

        try await httpClient.downloadFile(url: gpgKeysUrl, to: tmpFile)

#if os(Linux)
        // With linux, we can ask gpg to try an import to see if the file is valid
        // in a sandbox home directory to avoid contaminating the system
        let gpgHome = FileManager.default.temporaryDirectory.appendingPathComponent("swiftly-\(UUID())")
        try FileManager.default.createDirectory(atPath: gpgHome.path, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: gpgHome)
        }

        try Swiftly.currentPlatform.runProgram("gpg", "--import", tmpFile.path, quiet: false, env: ["GNUPGHOME": gpgHome.path])
#endif
    }

    @Test func getSwiftlyReleaseMetadataFromSwiftOrg() async throws {
        let httpClient = SwiftlyHTTPClient(httpRequestExecutor: HTTPRequestExecutorImpl())
        let currentRelease = try await httpClient.getCurrentSwiftlyRelease()
        #expect(throws: Never.self) { try currentRelease.swiftlyVersion }
    }

    @Test(
        arguments:
        [PlatformDefinition.macOS, .ubuntu2404, .ubuntu2204, .rhel9, .fedora39, .amazonlinux2, .debian12],
        [Components.Schemas.Architecture.x8664, .aarch64]
    ) func getToolchainMetdataFromSwiftOrg(_ platform: PlatformDefinition, _ arch: Components.Schemas.Architecture) async throws {
        let httpClient = SwiftlyHTTPClient(httpRequestExecutor: HTTPRequestExecutorImpl())

        let branches: [ToolchainVersion.Snapshot.Branch] = [
            .main,
            .release(major: 6, minor: 1), // This is available in swift.org API
        ]

        // GIVEN: we have a swiftly http client with swift.org metadata capability
        // WHEN: we ask for the first five releases of a supported platform in a supported arch
        let releases = try await httpClient.getReleaseToolchains(platform: platform, arch: arch, limit: 5)
        // THEN: we get at least 1 release
        #expect(1 <= releases.count)

        for branch in branches {
            // GIVEN: we have a swiftly http client with swift.org metadata capability
            // WHEN: we ask for the first five snapshots on a branch for a supported platform and arch
            let snapshots = try await httpClient.getSnapshotToolchains(platform: platform, arch: arch.value2!, branch: branch, limit: 5)
            // THEN: we get at least 3 releases
            #expect(3 <= snapshots.count)
        }
    }
}
