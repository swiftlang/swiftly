@testable import Swiftly
@testable import SwiftlyCore
import XCTest

final class HTTPClientTests: SwiftlyTests {
    func testGet() async throws {
        // GIVEN: we have a swiftly http client
        // WHEN: we make get request for a particular type of JSON
        var releases: [SwiftOrgRelease] = try await SwiftlyCore.httpClient.getFromJSON(
            url: "https://swift.org/api/v1/install/releases.json",
            type: [SwiftOrgRelease].self,
            headers: [:]
        )
        // THEN: we get a decoded JSON response
        XCTAssertTrue(releases.count > 0)

        // GIVEN: we have a swiftly http client
        // WHEN: we make a request to an invalid URL path
        var exceptionThrown = false
        do {
            releases = try await SwiftlyCore.httpClient.getFromJSON(
                url: "https://swift.org/api/v1/install/releases-invalid.json",
                type: [SwiftOrgRelease].self,
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
                type: [SwiftOrgRelease].self,
                headers: [:]
            )
        } catch {
            exceptionThrown = true
        }
        // THEN: we receive an exception
        XCTAssertTrue(exceptionThrown)
    }

    func testGetMetdataFromSwiftOrg() async throws {
        let supportedPlatforms = [
            PlatformDefinition.macOS,
            PlatformDefinition.ubuntu2204,
            PlatformDefinition.ubuntu2004,
            // PlatformDefinition.ubuntu1804,
            PlatformDefinition.rhel9,
            PlatformDefinition.amazonlinux2,
        ]

        let branches = [
            ToolchainVersion.Snapshot.Branch.main,
            ToolchainVersion.Snapshot.Branch.release(major: 6, minor: 0), // This is available in swift.org API
            ToolchainVersion.Snapshot.Branch.release(major: 5, minor: 9), // This is only available using GH API
        ]

        for arch in ["x86_64", "aarch64"] {
            for platform in supportedPlatforms {
                // GIVEN: we have a swiftly http client with swift.org metadata capability
                // WHEN: we ask for the first five releases of a supported platform in a supported arch
                let releases = try await SwiftlyCore.httpClient.getReleaseToolchains(platform: platform, arch: arch, limit: 5)
                // THEN: we get five releases
                XCTAssertEqual(5, releases.count)

                for branch in branches {
                    // GIVEN: we have a swiftly http client with swift.org metadata capability
                    // WHEN: we ask for the first five snapshots on a branch for a supported platform and arch
                    let snapshots = try await SwiftlyCore.httpClient.getSnapshotToolchains(platform: platform, arch: arch, branch: branch, limit: 5)
                    // THEN: we get five snapshots
                    XCTAssertEqual(5, snapshots.count)
                }
            }
        }
    }
}
