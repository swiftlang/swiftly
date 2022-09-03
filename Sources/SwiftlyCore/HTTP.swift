import AsyncHTTPClient
import Foundation
import NIOFoundationCompat
import NIO
import NIOHTTP1
import _StringProcessing

/// HTTPClient wrapper used for interfacing with various APIs and downloading things.
public class HTTP {
    private static let client = HTTPClientWrapper()

    private struct Response {
        let status: HTTPResponseStatus
        let buffer: ByteBuffer
    }

    private static func makeRequest(url: String) throws -> HTTPClient.Request {
        var request = try HTTPClient.Request(url: url)
        request.headers.add(name: "User-Agent", value: "swiftly")
        return request
    }

    private static func get(url: String) async throws -> Response {
        var request = HTTPClientRequest(url: url)
        request.headers.add(name: "User-Agent", value: "swiftly")
        let response = try await Self.client.inner.execute(request, timeout: .seconds(30))

        // if defined, the content-length headers announces the size of the body
        let expectedBytes = response.headers.first(name: "content-length").flatMap(Int.init) ?? 1024 * 1024
        return Response(status: response.status, buffer: try await response.body.collect(upTo: expectedBytes))
    }

    /// Decode the provided type `T` from the JSON body of the response from a GET request
    /// to the given URL.
    public static func getFromJSON<T: Decodable>(url: String, type: T.Type) async throws -> T {
        let response = try await Self.get(url: url)

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

    /// Get a list of releases on the apple/swift GitHub repository.
    /// The releases are returned in "pages" of `perPage` releases (default 100). The page argument specifies the
    /// page number.
    ///
    /// The results are returned in lexicographic order.
    private static func getReleases(page: Int, perPage: Int = 100) async throws -> [GitHubTag] {
        let url = "https://api.github.com/repos/apple/swift/releases?per_page=\(perPage)&page=\(page)"
        return try await Self.getFromJSON(url: url, type: [GitHubTag].self)
    }

    /// Return an array of released Swift versions that match the given filter, up to the provided
    /// limit (default unlimited).
    public static func getReleaseToolchains(
        limit: Int? = nil,
        filter: ((ToolchainVersion.StableRelease) -> Bool)? = nil
    ) async throws -> [ToolchainVersion.StableRelease] {
        let filterMap = { (gh: GitHubTag) -> ToolchainVersion.StableRelease? in
            let release = try gh.parseStableRelease()

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
        return try await Self.getFromJSON(url: url, type: [GitHubTag].self)
    }

    /// Return an array of Swift snapshots that match the given filter, up to the provided
    /// limit (default unlimited).
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

    public static func downloadFile(
        url: String,
        to destination: String,
        reportProgress: @escaping (FileDownloadDelegate.Progress) -> Void
    ) async throws {
        let delegate = try FileDownloadDelegate(
            path: destination,
            reportProgress: reportProgress
        )
        let request = try Self.makeRequest(url: url)
        let delegateTask = Self.client.inner.execute(request: request, delegate: delegate)
        let _ = try await delegateTask.futureResult.get()
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

    fileprivate func parseStableRelease() throws -> ToolchainVersion.StableRelease {
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
