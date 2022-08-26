import AsyncHTTPClient
import Foundation
import NIOFoundationCompat
import NIO

/// HTTPClient wrapper used for interfacing with various APIs and downloading things.
public class HTTP {
    private static let client = HTTPClientWrapper()

    private static func makeRequest(url: String) throws -> HTTPClient.Request {
        var request = try HTTPClient.Request(url: url)
        request.headers.add(name: "User-Agent", value: "swiftly")
        return request
    }

    private static func get(url: String) async throws -> ByteBuffer {
        var request = HTTPClientRequest(url: url)
        request.headers.add(name: "User-Agent", value: "swiftly")
        let response = try await Self.client.inner.execute(request, timeout: .seconds(30))

        // if defined, the content-length headers announces the size of the body
        let expectedBytes = response.headers.first(name: "content-length").flatMap(Int.init) ?? 1024 * 1024
        return try await response.body.collect(upTo: expectedBytes)
    }

    /// Decode the provided type `T` from the JSON body of the response from a GET request
    /// to the given URL.
    public static func getFromJSON<T: Decodable>(url: String, type: T.Type) async throws -> T {
        let buffer = try await Self.get(url: url)
        return try JSONDecoder().decode(type.self, from: buffer)
    }

    /// Get the latest `n` stable releases of Swift via the GitHub API.
    public static func getLatestReleases(numberOfReleases n: Int? = nil) async throws -> [GitHubRelease] {
        var url = "https://api.github.com/repos/apple/swift/releases"
        if let n {
            url += "?per_page=\(n)"
        }
        return try await Self.getFromJSON(url: url, type: [GitHubRelease].self)
    }

    public static func downloadFile(url: String, to destination: String, reportProgress: @escaping (FileDownloadDelegate.Progress) -> Void) async throws {
        let delegate = try FileDownloadDelegate(
            path: destination,
            reportProgress: reportProgress // { progress in
            //     if let total = progress.totalBytes {
            //         let progressPercentage = Int(Double(progress.receivedBytes) / Double(total) * 100.0)
            //         print("download \(Double(progress.receivedBytes) / Double(total) * 100.0)% complete")
            //     } else {
            //         print("downloaded \(progress.receivedBytes) bytes")
            //     }
            // }
        )
        let request = try Self.makeRequest(url: url)
        let delegateTask = Self.client.inner.execute(request: request, delegate: delegate)
        let idk = try await delegateTask.futureResult.get()
    }
}

private class HTTPClientWrapper {
    fileprivate let inner = HTTPClient(eventLoopGroupProvider: .createNew)

    deinit {
        try? self.inner.syncShutdown()
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
