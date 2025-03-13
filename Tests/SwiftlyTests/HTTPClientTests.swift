@testable import Swiftly
@testable import SwiftlyCore
import XCTest

final class HTTPClientTests: SwiftlyTests {
    func testGet() async throws {
        // GIVEN: we have a swiftly http client
        // WHEN: we make get request for a particular type of JSON
        var releases: [Components.Schemas.Release] = try await SwiftlyCore.httpClient.getFromJSON(
            url: "https://www.swift.org/api/v1/install/releases.json",
            type: [Components.Schemas.Release].self,
            headers: [:]
        )
        // THEN: we get a decoded JSON response
        XCTAssertTrue(releases.count > 0)

        // GIVEN: we have a swiftly http client
        // WHEN: we make a request to an invalid URL path
        var exceptionThrown = false
        do {
            releases = try await SwiftlyCore.httpClient.getFromJSON(
                url: "https://www.swift.org/api/v1/install/releases-invalid.json",
                type: [Components.Schemas.Release].self,
                headers: [:]
            )
        } catch {
            exceptionThrown = true
        }
        // THEN: we receive an exception
        XCTAssertTrue(exceptionThrown)

        // GIVEN: we have a swiftly http client
        // WHEN: we make a request to an invalid host path
        exceptionThrown = false
        do {
            releases = try await SwiftlyCore.httpClient.getFromJSON(
                url: "https://invalid.swift.org/api/v1/install/releases.json",
                type: [Components.Schemas.Release].self,
                headers: [:]
            )
        } catch {
            exceptionThrown = true
        }
        // THEN: we receive an exception
        XCTAssertTrue(exceptionThrown)
    }

    func testGetSwiftlyReleaseMetadataFromSwiftOrg() async throws {
        let currentRelease = try await SwiftlyCore.httpClient.getCurrentSwiftlyRelease()
        XCTAssertNoThrow(try currentRelease.swiftlyVersion)
    }

    func testGetToolchainMetdataFromSwiftOrg() async throws {
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

        for arch in [Components.Schemas.Architecture(value1: Components.Schemas.KnownArchitecture.x8664), Components.Schemas.Architecture(value1: Components.Schemas.KnownArchitecture.aarch64)] {
            for platform in supportedPlatforms {
                // GIVEN: we have a swiftly http client with swift.org metadata capability
                // WHEN: we ask for the first five releases of a supported platform in a supported arch
                let releases = try await SwiftlyCore.httpClient.getReleaseToolchains(platform: platform, arch: arch, limit: 5)
                // THEN: we get at least 1 release
                XCTAssertTrue(1 <= releases.count)

                if newPlatforms.contains(platform) { continue } // Newer distros don't have main snapshots yet

                for branch in branches {
                    // GIVEN: we have a swiftly http client with swift.org metadata capability
                    // WHEN: we ask for the first five snapshots on a branch for a supported platform and arch
                    let snapshots = try await SwiftlyCore.httpClient.getSnapshotToolchains(platform: platform, arch: String(describing: arch), branch: branch, limit: 5)
                    // THEN: we get at least 3 releases
                    XCTAssertTrue(3 <= snapshots.count)
                }
            }
        }
    }
}
