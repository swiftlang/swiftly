import AsyncHTTPClient
import Foundation
import NIOFoundationCompat
import NIO
import NIOHTTP1
import _StringProcessing

/// HTTPClient wrapper used for interfacing with various APIs and downloading things.
public class HTTP {
    private static let client = HTTPClientWrapper()

    /// The GitHub authentication token to use for any requests made to the GitHub API.
    public static var githubToken: String? = nil

    private struct Response {
        let status: HTTPResponseStatus
        let buffer: ByteBuffer
    }

    private static func makeRequest(url: String) -> HTTPClientRequest {
        var request = HTTPClientRequest(url: url)
        request.headers.add(name: "User-Agent", value: "swiftly")
        return request
    }

    private static func get(url: String, headers: [String: String]) async throws -> Response {
        var request = Self.makeRequest(url: url)

        for (k, v) in headers {
            request.headers.add(name: k, value: v)
        }

        let response = try await Self.client.inner.execute(request, timeout: .seconds(30))

        // if defined, the content-length headers announces the size of the body
        let expectedBytes = response.headers.first(name: "content-length").flatMap(Int.init) ?? 1024 * 1024
        return Response(status: response.status, buffer: try await response.body.collect(upTo: expectedBytes))
    }

    /// Decode the provided type `T` from the JSON body of the response from a GET request
    /// to the given URL.
    public static func getFromJSON<T: Decodable>(
        url: String,
        type: T.Type,
        headers: [String: String] = [:]
    ) async throws -> T {
        let response = try await Self.get(url: url, headers: headers)

        guard case .ok = response.status else {
            var message = "received status \"\(response.status)\" when reaching \(url)"
            if let json = response.buffer.getString(at: 0, length: response.buffer.readableBytes) {
                message += ": \(json)"
            }
            throw Error(message: message)
        }

        return try JSONDecoder().decode(type.self, from: response.buffer)
    }

    /// Function used to iterate over pages of GitHub tags/releases and map + filter them down.
    /// The `fetch` closure is used to retrieve the next page of results. It accepts the page number as its argument.
    /// The `filterMap` closure maps the input GitHub tag to an output. If it returns nil, it will not be included
    /// in the returned array.
    private static func mapGithubTags<T>(
        limit: Int?,
        filterMap: ((GitHubTag) throws -> T?),
        fetch: (Int) async throws -> [GitHubTag]
    ) async throws -> [T] {
        var page = 1
        var found: [T] = []

        let limit = limit ?? Int.max

        while true {
            let results = try await fetch(page)
            guard !results.isEmpty else {
                return found
            }

            for githubRelease in results {
                guard let out = try filterMap(githubRelease) else {
                    continue
                }
                found.append(out)

                guard found.count < limit else {
                    return found
                }
            }

            page += 1
        }
    }

    /// Get a JSON response from the GitHub REST API.
    /// This will use the authorization token set, if any.
    private static func getFromGitHub<T: Decodable>(url: String) async throws -> T {
        var headers: [String: String] = [:]
        if let token = Self.githubToken {
            headers["Authorization"] = "Bearer \(token)"
        }

        return try await Self.getFromJSON(url: url, type: T.self, headers: headers)
    }

    /// Get a list of releases on the apple/swift GitHub repository.
    /// The releases are returned in "pages" of `perPage` releases (default 100). The page argument specifies the
    /// page number.
    ///
    /// The results are returned in lexicographic order.
    private static func getReleases(page: Int, perPage: Int = 100) async throws -> [GitHubTag] {
        let url = "https://api.github.com/repos/apple/swift/releases?per_page=\(perPage)&page=\(page)"
        return try await Self.getFromGitHub(url: url)
    }

    /// Return an array of released Swift versions that match the given filter, up to the provided
    /// limit (default unlimited).
    ///
    /// TODO: retrieve these directly from Apple instead of through GitHub.
    public static func getReleaseToolchains(
        limit: Int? = nil,
        filter: ((ToolchainVersion.StableRelease) -> Bool)? = nil
    ) async throws -> [ToolchainVersion.StableRelease] {
        let filterMap = { (gh: GitHubTag) -> ToolchainVersion.StableRelease? in
            guard let release = try gh.parseStableRelease() else {
                return nil
            }

            if let filter {
                guard filter(release) else {
                    return nil
                }
            }

            return release
        }

        return try await Self.mapGithubTags(limit: limit, filterMap: filterMap) { page in
            try await Self.getReleases(page: page)
        }
    }

    /// Get a list of tags on the apple/swift GitHub repository.
    /// The tags are returned in pages of 100. The page argument specifies the page number.
    ///
    /// The results are returned in lexicographic order.
    private static func getTags(page: Int) async throws -> [GitHubTag] {
        let url = "https://api.github.com/repos/apple/swift/tags?per_page=100&page=\(page)"
        return try await Self.getFromGitHub(url: url)
    }

    /// Return an array of Swift snapshots that match the given filter, up to the provided
    /// limit (default unlimited).
    ///
    /// TODO: retrieve these directly from Apple instead of through GitHub.
    public static func getSnapshotToolchains(
        limit: Int? = nil,
        filter: ((ToolchainVersion.Snapshot) -> Bool)? = nil
    ) async throws -> [ToolchainVersion.Snapshot] {
        let filter = { (gh: GitHubTag) -> ToolchainVersion.Snapshot? in
            guard let snapshot = try gh.parseSnapshot() else {
                return nil
            }

            if let filter {
                guard filter(snapshot) else {
                    return nil
                }
            }

            return snapshot
        }

        return try await Self.mapGithubTags(limit: limit, filterMap: filter) { page in
            try await Self.getTags(page: page)
        }
    }

    public struct DownloadProgress {
        public let receivedBytes: Int
        public let totalBytes: Int?
    }

    public struct DownloadNotFoundError: LocalizedError {
        public let url: String
    }

    public static func downloadToolchain(
        url: String,
        to destination: String,
        reportProgress: @escaping (DownloadProgress) -> Void
    ) async throws {
        let fileHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: destination))
        defer {
            try? fileHandle.close()
        }

        let request = self.makeRequest(url: url)
        let response = try await Self.client.inner.execute(request, timeout: .seconds(30))

        guard case response.status = HTTPResponseStatus.ok else {
            throw Error(message: "Received \(response.status) when trying to download \(url)")
        }

        // Unknown download.swift.org paths redirect to a 404 page which then returns a 200 status.
        // As a heuristic for if we've hit the 404 page, we check to see if the content is HTML.
        guard !response.headers["Content-Type"].contains(where: { $0.contains("text/html") }) else {
            throw DownloadNotFoundError(url: url)
        }

        // if defined, the content-length headers announces the size of the body
        let expectedBytes = response.headers.first(name: "content-length").flatMap(Int.init)

        var receivedBytes = 0
        for try await buffer in response.body {
            receivedBytes += buffer.readableBytes

            try buffer.withUnsafeReadableBytes { bufferPtr in
                try fileHandle.write(contentsOf: bufferPtr)
            }
            reportProgress(DownloadProgress(receivedBytes: receivedBytes, totalBytes: expectedBytes))
        }

        try fileHandle.synchronize()
    }
}

private class HTTPClientWrapper {
    fileprivate let inner = HTTPClient(eventLoopGroupProvider: .createNew)

    deinit {
        try? self.inner.syncShutdown()
    }
}

/// Model of a GitHub REST API tag/release object.
private struct GitHubTag: Decodable {
    /// The name of the release.
    /// e.g. "Swift a.b[.c] Release" or "swift-5.7-DEVELOPMENT-SNAPSHOT-2022-08-30-a".
    let name: String

    fileprivate func parseStableRelease() throws -> ToolchainVersion.StableRelease? {
        // names look like Swift a.b.c Release
        let parts = self.name.split(separator: " ")
        guard parts.count >= 2 else {
            return nil
        }

        // versions can be a.b.c or a.b for .0 releases
        let versionParts = parts[1].split(separator: ".")
        guard
            versionParts.count >= 2,
            let major = Int(versionParts[0]),
            let minor = Int(versionParts[1])
        else {
            return nil
        }

        let patch: Int
        if versionParts.count == 3 {
            guard let p = Int(versionParts[2]) else {
                return nil
            }
            patch = p
        } else {
            patch = 0
        }

        return ToolchainVersion.StableRelease(major: major, minor: minor, patch: patch)
    }

    private static let snapshotRegex: Regex<(Substring, Substring?, Substring?, Substring)> =
        try! Regex("swift(?:-(\\d+)\\.(\\d+))?-DEVELOPMENT-SNAPSHOT-(\\d{4}-\\d{2}-\\d{2})")

    fileprivate func parseSnapshot() throws -> ToolchainVersion.Snapshot? {
        guard let match = try Self.snapshotRegex.firstMatch(in: self.name) else {
            return nil
        }

        let branch: ToolchainVersion.Snapshot.Branch
        if let majorString = match.output.1, let minorString = match.output.2 {
            guard let major = Int(majorString), let minor = Int(minorString) else {
                throw Error(message: "malformatted release branch: \"\(majorString).\(minorString)\"")
            }
            branch = .release(major: major, minor: minor)
        } else {
            branch = .main
        }

        return ToolchainVersion.Snapshot(branch: branch, date: String(match.output.3))
    }
}
