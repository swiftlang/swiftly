@testable import Swiftly
@testable import SwiftlyCore
import Testing

@Suite struct HTTPClientTests {
    @Test func getSwiftlyReleaseMetadataFromSwiftOrg() async throws {
        let httpClient = SwiftlyHTTPClient(httpRequestExecutor: HTTPRequestExecutorImpl())
        let currentRelease = try await httpClient.getCurrentSwiftlyRelease()
        #expect(throws: Never.self) { try currentRelease.swiftlyVersion }
    }

    @Test func getToolchainMetdataFromSwiftOrg() async throws {
        let httpClient = SwiftlyHTTPClient(httpRequestExecutor: HTTPRequestExecutorImpl())

        let supportedPlatforms: [PlatformDefinition] = [
            .macOS,
            .ubuntu2404,
            .ubuntu2204,
            .ubuntu2004,
            // .ubuntu1804, // There are no releases for Ubuntu 18.04 in the branches being tested below
            .rhel9,
            .fedora39,
            .amazonlinux2,
            .debian12,
        ]

        let newPlatforms: [PlatformDefinition] = [
            .ubuntu2404,
            .fedora39,
            .debian12,
        ]

        let branches: [ToolchainVersion.Snapshot.Branch] = [
            .main,
            .release(major: 6, minor: 0), // This is available in swift.org API
        ]

        for arch in [Components.Schemas.Architecture.x8664, Components.Schemas.Architecture.aarch64] {
            for platform in supportedPlatforms {
                // GIVEN: we have a swiftly http client with swift.org metadata capability
                // WHEN: we ask for the first five releases of a supported platform in a supported arch
                let releases = try await httpClient.getReleaseToolchains(platform: platform, arch: arch, limit: 5)
                // THEN: we get at least 1 release
                #expect(1 <= releases.count)

                if newPlatforms.contains(platform) { continue } // Newer distros don't have main snapshots yet

                for branch in branches {
                    // GIVEN: we have a swiftly http client with swift.org metadata capability
                    // WHEN: we ask for the first five snapshots on a branch for a supported platform and arch
                    let snapshots = try await httpClient.getSnapshotToolchains(platform: platform, arch: arch.value2!, branch: branch, limit: 5)
                    // THEN: we get at least 3 releases
                    #expect(3 <= snapshots.count)
                }
            }
        }
    }
}
