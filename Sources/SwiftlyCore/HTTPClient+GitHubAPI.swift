import _StringProcessing
import AsyncHTTPClient
import Foundation

public struct SwiftlyGitHubRelease: Codable {
    public let tag: String

    enum CodingKeys: String, CodingKey {
        case tag = "tag_name"
    }
}

extension SwiftlyHTTPClient {
    /// Get a JSON response from the GitHub REST API.
    /// This will use the authorization token set, if any.
    public func getFromGitHub<T: Decodable>(url: String) async throws -> T {
        var headers: [String: String] = [:]
        if let token = self.githubToken ?? ProcessInfo.processInfo.environment["SWIFTLY_GITHUB_TOKEN"] {
            headers["Authorization"] = "Bearer \(token)"
        }

        return try await self.getFromJSON(url: url, type: T.self, headers: headers)
    }
}
