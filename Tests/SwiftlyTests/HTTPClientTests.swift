import AsyncHTTPClient
import Foundation
@testable import Swiftly
@testable import SwiftlyCore
import SwiftlyWebsiteAPI
import SystemPackage
import Testing

@Suite(.serialized) struct HTTPClientTests {
    @Test func getSwiftOrgGPGKeys() async throws {
        let tmpFile = mktemp()
        try await create(file: tmpFile, contents: nil)

        try await withTemporary(files: tmpFile) {
            let httpClient = SwiftlyHTTPClient(httpRequestExecutor: HTTPRequestExecutorImpl())

            try await retry {
                try await httpClient.getGpgKeys().download(to: tmpFile)
            }

            try await withGpg { runGpg in
                try runGpg(["--import", "\(tmpFile)"])
            }
        }
    }

    @Test func getSwiftToolchain() async throws {
        let tmpFile = mktemp()
        try await create(file: tmpFile, contents: nil)
        let tmpFileSignature = mktemp(ext: ".sig")
        try await create(file: tmpFileSignature, contents: nil)
        let keysFile = mktemp(ext: ".asc")
        try await create(file: keysFile, contents: nil)

        try await withTemporary(files: tmpFile, tmpFileSignature, keysFile) {
            let httpClient = SwiftlyHTTPClient(httpRequestExecutor: HTTPRequestExecutorImpl())

            let toolchainFile = ToolchainFile(category: "swift-6.0-release", platform: "ubuntu2404", version: "swift-6.0-RELEASE", file: "swift-6.0-RELEASE-ubuntu24.04.tar.gz")

            try await retry {
                try await httpClient.getSwiftToolchainFile(toolchainFile).download(to: tmpFile)
            }

            try await retry {
                try await httpClient.getSwiftToolchainFileSignature(toolchainFile).download(to: tmpFileSignature)
            }

            try await withGpg { runGpg in
                try await httpClient.getGpgKeys().download(to: keysFile)
                try runGpg(["--import", "\(keysFile)"])
                try runGpg(["--verify", "\(tmpFileSignature)", "\(tmpFile)"])
            }
        }
    }

    @Test func getSwiftlyRelease() async throws {
        let tmpFile = mktemp()
        try await create(file: tmpFile, contents: nil)
        let tmpFileSignature = mktemp(ext: ".sig")
        try await create(file: tmpFileSignature, contents: nil)
        let keysFile = mktemp(ext: ".asc")
        try await create(file: keysFile, contents: nil)

        try await withTemporary(files: tmpFile, tmpFileSignature, keysFile) {
            let httpClient = SwiftlyHTTPClient(httpRequestExecutor: HTTPRequestExecutorImpl())

            let swiftlyURL = try #require(URL(string: "https://download.swift.org/swiftly/linux/swiftly-x86_64.tar.gz"))

            try await retry {
                try await httpClient.getSwiftlyRelease(url: swiftlyURL).download(to: tmpFile)
            }

            try await retry {
                try await httpClient.getSwiftlyReleaseSignature(url: swiftlyURL.appendingPathExtension("sig")).download(to: tmpFileSignature)
            }

            try await withGpg { runGpg in
                try await httpClient.getGpgKeys().download(to: keysFile)
                try runGpg(["--import", "\(keysFile)"])
                try runGpg(["--verify", "\(tmpFileSignature)", "\(tmpFile)"])
            }
        }
    }

    @Test func getSwiftlyReleaseMetadataFromSwiftOrg() async throws {
        let httpClient = SwiftlyHTTPClient(httpRequestExecutor: HTTPRequestExecutorImpl())
        do {
            let currentRelease = try await httpClient.getCurrentSwiftlyRelease()
            #expect(throws: Never.self) { try currentRelease.swiftlyVersion }
        } catch {
            let currentRelease = try await httpClient.getCurrentSwiftlyRelease()
            #expect(throws: Never.self) { try currentRelease.swiftlyVersion }
        }
    }

    @Test(
        arguments:
        [PlatformDefinition.macOS, .ubuntu2404, .ubuntu2204, .rhel9, .fedora39, .amazonlinux2, .debian12],
        [SwiftlyWebsiteAPI.Components.Schemas.Architecture.x8664, .aarch64]
    ) func getToolchainMetdataFromSwiftOrg(_ platform: PlatformDefinition, _ arch: SwiftlyWebsiteAPI.Components.Schemas.Architecture) async throws {
        guard case let pd = try await Swiftly.currentPlatform.detectPlatform(SwiftlyTests.ctx, disableConfirmation: true, platform: nil), pd != PlatformDefinition.rhel9 && pd != PlatformDefinition.ubuntu2004 else {
            return
        }

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

private func withGpg(_ body: (([String]) throws -> Void) async throws -> Void) async throws {
#if os(Linux)
    // With linux, we can ask gpg to try an import to see if the file is valid
    // in a sandbox home directory to avoid contaminating the system
    let gpgHome = mktemp()
    try await mkdir(atPath: gpgHome, parents: true)
    try await withTemporary(files: gpgHome) {
        func runGpg(arguments: [String]) throws {
            try Swiftly.currentPlatform.runProgram(["gpg"] + arguments, quiet: false, env: ["GNUPGHOME": gpgHome.string])
        }

        try await body(runGpg)
    }
#endif
}

private func retry(_ body: () async throws -> Void) async throws {
    do {
        try await body()
    } catch {
        // Retry once to improve CI resiliency
        try await body()
    }
}
