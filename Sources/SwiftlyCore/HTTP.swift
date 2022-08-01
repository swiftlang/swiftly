import AsyncHTTPClient
import Foundation
import NIOFoundationCompat

/// HTTPClient wrapper used for interfacing with various APIs and downloading things.
public class HTTP {
    let client: HTTPClient

    public init() {
        self.client = HTTPClient(eventLoopGroupProvider: .createNew)
    }

    deinit {
        try? self.client.syncShutdown()
    }

    /// Decode the provided type `T` from the JSON body of the response from a GET request
    /// to the given URL.
    public func getFromJSON<T: Decodable>(url: String, type: T.Type) async throws -> T {
        var request = HTTPClientRequest(url: url)
        request.headers.add(name: "User-Agent", value: "swiftly")
        let response = try await client.execute(request, timeout: .seconds(30))

        // if defined, the content-length headers announces the size of the body
        let expectedBytes = response.headers.first(name: "content-length").flatMap(Int.init) ?? 1024 * 1024
        let buffer = try await response.body.collect(upTo: expectedBytes)

        return try JSONDecoder().decode(type.self, from: buffer)
    }

    /// Get the latest `n` stable releases of Swift via the GitHub API.
    public func getLatestReleases(numberOfReleases n: Int? = nil) async throws -> [GitHubRelease] {
        var url = "https://api.github.com/repos/apple/swift/releases"
        if let n {
            url += "?per_page=\(n)"
        }
        return try await self.getFromJSON(url: url, type: [GitHubRelease].self)
    }
}

/// Model of a GitHub REST API release object.
public struct GitHubRelease: Decodable {
    /// The name of the release.
    /// e.g. "Swift a.b[.c] Release".
    let name: String

    public func parse() throws -> ToolchainVersion.StableRelease {
        // names look like Swift a.b.c Release
        let parts = self.name.split(separator: " ")
        guard parts.count >= 2 else {
            throw Error(message: "Malformatted release name from GitHub API: \(self.name)")
        }

        // versions can be a.b.c or a.b for .0 releases
        let versionParts = parts[1].split(separator: ".")
        guard
            versionParts.count >= 2,
            let major = Int(versionParts[0]),
            let minor = Int(versionParts[1])
        else {
            throw Error(message: "Malformatted release version from GitHub API: \(parts[1])")
        }

        let patch: Int
        if versionParts.count == 3 {
            guard let p = Int(versionParts[2]) else {
                throw Error(message: "Malformatted patch version from GitHub API: \(versionParts[2])")
            }
            patch = p
        } else {
            patch = 0
        }

        return ToolchainVersion.StableRelease(major: major, minor: minor, patch: patch)
    }
}
