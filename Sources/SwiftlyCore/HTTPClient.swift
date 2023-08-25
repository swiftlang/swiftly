import _StringProcessing
import AsyncHTTPClient
import Foundation
import NIO
import NIOFoundationCompat
import NIOHTTP1

/// HTTPClient wrapper used for interfacing with various APIs and downloading things.
public class HTTP {
    private static let client = HTTPClientWrapper()

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

    /// Return an array of released Swift versions that match the given filter, up to the provided
    /// limit (default unlimited).
    ///
    /// TODO: retrieve these directly from swift.org instead of through GitHub.
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

        return try await Self.mapGitHubTags(limit: limit, filterMap: filterMap) { page in
            try await Self.getReleases(page: page)
        }
    }

    /// Return an array of Swift snapshots that match the given filter, up to the provided
    /// limit (default unlimited).
    ///
    /// TODO: retrieve these directly from swift.org instead of through GitHub.
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

        return try await Self.mapGitHubTags(limit: limit, filterMap: filter) { page in
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
    fileprivate let inner = HTTPClient(eventLoopGroupProvider: .singleton)

    deinit {
        try? self.inner.syncShutdown()
    }
}
