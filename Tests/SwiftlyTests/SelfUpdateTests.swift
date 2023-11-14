import AsyncHTTPClient
import Foundation
@testable import Swiftly
@testable import SwiftlyCore
import XCTest
import NIO

final class SelfUpdateTests: SwiftlyTests {
    private static var newMajorVersion: String {
        "\(Swiftly.version.major + 1).0.0"
    }

    private static var newMinorVersion: String {
        "\(Swiftly.version.major).\(Swiftly.version.minor + 1).0)"
    }

    private static var newPatchVersion: String {
        "\(Swiftly.version.major).\(Swiftly.version.minor).\(Swiftly.version.patch + 1))"
    }

    private static func makeMockHTTPClient(latestVersion: String) -> SwiftlyHTTPClient {
        return .mocked { request in
            guard let url = URL(string: request.url) else {
                throw SwiftlyTestError(message: "invalid url \(request.url)")
            }

            switch url.host {
            case "api.github.com":
                let nextRelease = try SwiftlyGitHubRelease(tag: latestVersion)
                var buffer = ByteBuffer()
                try buffer.writeJSONEncodable(nextRelease)
                return HTTPClientResponse(body: .bytes(buffer))
            case "download.swift.org":
                fatalError("blah")
            default:
                throw SwiftlyTestError(message: "unknown url host: \(url.host)")
            }

        }
    }

    /// Verify updating the most up-to-date toolchain has no effect.
    func testUpdateLatest() async throws {
        try await self.withTestHome {
            var update = try self.parseCommand(Update.self, ["self-update"])

            update.httpClient = .mocked { request in
                guard let url = URL(string: request.url) else {
                    throw SwiftlyTestError(message: "invalid url \(request.url)")
                }

                switch url.host {
                case "api.github.com":
                    let nextVersion = "TODO"
                    let nextRelease = SwiftlyGitHubRelease(name: nextVersion)
                    var buffer = ByteBuffer()
                    try buffer.writeJSONEncodable(nextRelease)
                    return HTTPClientResponse(body: .bytes(buffer))
                case "download.swift.org":
                    return 12
                default:
                    throw SwiftlyTestError(message: "unknown url host: \(url.host)")
                }
            }
            try await update.run()

        }
    }
}
