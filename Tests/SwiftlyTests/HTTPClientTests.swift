@testable import Swiftly
@testable import SwiftlyCore
import XCTest

final class HTTPClientTests: SwiftlyTests {
    func testGet() async throws {
        // GIVEN: we have a swiftly http client
        // WHEN: we make get request for a particular type of JSON
        var releases: [GitHubRelease] = try await SwiftlyCore.httpClient.getFromJSON(
            url: "https://api.github.com/repos/apple/swift/releases?per_page=100&page=1",
            type: [GitHubRelease].self,
            headers: [:]
        )
        // THEN: we get a decoded JSON response
        XCTAssertTrue(releases.count > 0)

        // GIVEN: we have a swiftly http client
        // WHEN: we make a request to an invalid URL path
        var exceptionThrown = false
        do {
            releases = try await SwiftlyCore.httpClient.getFromJSON(
                url: "https://api.github.com/repos/apple/swift/releases2",
                type: [GitHubRelease].self,
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
                url: "https://inavlid.github.com/repos/apple/swift/releases",
                type: [GitHubRelease].self,
                headers: [:]
            )
        } catch {
            exceptionThrown = true
        }
        // THEN: we receive an exception
        XCTAssertTrue(exceptionThrown)
    }

    func testGetFromGitHub() async throws {
        // GIVEN: we have a swiftly http client with github capability
        // WHEN: we ask for the first page of releases with page size 5
        var releases = try await SwiftlyCore.httpClient.getReleases(page: 1, perPage: 5)
        // THEN: we get five releases
        XCTAssertEqual(5, releases.count)

        let firstRelease = releases[0]

        // GIVEN: we have a swiftly http client with github capability
        // WHEN: we ask for the second page of releases with page size 5
        releases = try await SwiftlyCore.httpClient.getReleases(page: 2, perPage: 5)
        // THEN: we get five different releases
        XCTAssertEqual(5, releases.count)
        XCTAssertTrue(releases[0].name != firstRelease.name)

        // GIVEN: we have a swiftly http client with github capability
        // WHEN: we ask for the first page of tags
        var tags = try await SwiftlyCore.httpClient.getTags(page: 1)
        // THEN: we get a collection of tags
        XCTAssertTrue(tags.count > 0)

        let firstTag = tags[0]

        // GIVEN: we have a swiftly http client with github capability
        // WHEN: we ask for the second page of tags
        tags = try await SwiftlyCore.httpClient.getTags(page: 2)
        // THEN: we get a different collection of tags
        XCTAssertTrue(tags.count > 0)
        XCTAssertTrue(tags[0].name != firstTag.name)
    }
}
