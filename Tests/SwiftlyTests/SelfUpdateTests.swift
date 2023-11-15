import AsyncHTTPClient
import Foundation
import NIO
@testable import Swiftly
@testable import SwiftlyCore
import XCTest

final class SelfUpdateTests: SwiftlyTests {
    private static var newMajorVersion: String {
        "\(Swiftly.version.major + 1).0.0"
    }

    private static var newMinorVersion: String {
        "\(Swiftly.version.major).\(Swiftly.version.minor + 1).0"
    }

    private static var newPatchVersion: String {
        "\(Swiftly.version.major).\(Swiftly.version.minor).\(Swiftly.version.patch + 1)"
    }

    private static func makeMockHTTPClient(latestVersion: String) -> SwiftlyHTTPClient {
        .mocked { request in
            guard let url = URL(string: request.url) else {
                throw SwiftlyTestError(message: "invalid url \(request.url)")
            }

            switch url.host {
            case "api.github.com":
                let nextRelease = SwiftlyGitHubRelease(tag: latestVersion)
                var buffer = ByteBuffer()
                try buffer.writeJSONEncodable(nextRelease)
                return HTTPClientResponse(body: .bytes(buffer))
            case "github.com":
                var buffer = ByteBuffer()
                buffer.writeString(latestVersion)
                return HTTPClientResponse(body: .bytes(buffer))
            default:
                throw SwiftlyTestError(message: "unknown url host: \(String(describing: url.host))")
            }
        }
    }

    func runSelfUpdateTest(latestVersion: String, shouldUpdate: Bool = true) async throws {
        try await self.withTestHome {
            let swiftlyURL = Swiftly.currentPlatform.swiftlyBinDir.appendingPathComponent("swiftly", isDirectory: false)
            try "old".data(using: .utf8)!.write(to: swiftlyURL)

            var update = try self.parseCommand(SelfUpdate.self, ["self-update"])
            update.httpClient = Self.makeMockHTTPClient(latestVersion: latestVersion)
            try await update.run()

            let swiftly = try Data(contentsOf: swiftlyURL)

            if shouldUpdate {
                XCTAssertEqual(String(data: swiftly, encoding: .utf8), latestVersion)
            } else {
                XCTAssertEqual(String(data: swiftly, encoding: .utf8), "old")
            }
        }
    }

    /// Verify updating the most up-to-date toolchain has no effect.
    func testSelfUpdate() async throws {
        try await self.runSelfUpdateTest(latestVersion: Self.newPatchVersion)
        try await self.runSelfUpdateTest(latestVersion: Self.newMinorVersion)
        try await self.runSelfUpdateTest(latestVersion: Self.newMajorVersion)
    }

    func testSelfUpdateAlreadyUpToDate() async throws {
        try await self.runSelfUpdateTest(latestVersion: String(describing: Swiftly.version), shouldUpdate: false)
    }
}
