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
        let macOS = PlatformDefinition(name: "xcode", nameFull: "osx", namePretty: "macOS")
        let ubuntu2204 = PlatformDefinition(name: "ubuntu2204", nameFull: "ubuntu 22.04", namePretty: "Ubuntu 22.04")

        // GIVEN: we have a swiftly http client with swift.org metadata capability
        // WHEN: we ask for the first five macOS releases
        var releases = try await SwiftlyCore.httpClient.getReleaseToolchains(platform: macOS, limit: 5)
        // THEN: we get five releases
        XCTAssertEqual(5, releases.count)

        // GIVEN: we have a swiftly http client with swift.org metadata capability
        // WHEN: we ask for the first five 6.0 snapshots for macOS
        var snapshots = try await SwiftlyCore.httpClient.getSnapshotToolchains(platform: macOS, branch: ToolchainVersion.Snapshot.Branch.release(major: 6, minor: 0), limit: 5)
        // THEN: we get five snapshots
        XCTAssertEqual(5, snapshots.count)

        // GIVEN: we have a swiftly http client with swift.org metadata capability
        // WHEN: we ask for the first five ubuntu 2204 releases
        releases = try await SwiftlyCore.httpClient.getReleaseToolchains(platform: ubuntu2204, limit: 5)
        // THEN: we get five releases
        XCTAssertEqual(5, releases.count)

        // GIVEN: we have a swiftly http client with swift.org metadata capability
        // WHEN: we ask for the first five 6.0 snapshots for ubuntu 22.04
        snapshots = try await SwiftlyCore.httpClient.getSnapshotToolchains(platform: ubuntu2204, branch: ToolchainVersion.Snapshot.Branch.release(major: 6, minor: 0), limit: 5)
        // THEN: we get five snapshots
        XCTAssertEqual(5, snapshots.count)
    }
}
