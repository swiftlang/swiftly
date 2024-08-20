import _StringProcessing
import AsyncHTTPClient
import Foundation
import NIO
import NIOFoundationCompat
import NIOHTTP1

public protocol HTTPRequestExecutor {
    func execute(_ request: HTTPClientRequest, timeout: TimeAmount) async throws -> HTTPClientResponse
}

/// An `HTTPRequestExecutor` backed by the shared `HTTPClient`.
internal struct HTTPRequestExecutorImpl: HTTPRequestExecutor {
    public func execute(_ request: HTTPClientRequest, timeout: TimeAmount) async throws -> HTTPClientResponse {
        try await HTTPClient.shared.execute(request, timeout: timeout)
    }
}

private func makeRequest(url: String) -> HTTPClientRequest {
    var request = HTTPClientRequest(url: url)
    request.headers.add(name: "User-Agent", value: "swiftly/\(SwiftlyCore.version)")
    return request
}

struct SwiftOrgSwiftlyRelease: Codable {
    var name: String
}

struct SwiftOrgPlatform: Codable {
    var name: String
    var archs: [String]

    /// platformName is a mapping from the 'name' field of the swift.org platform object
    /// to swiftly's PlatformDefinition name.
    var platformName: String {
        switch self.name {
        case "Ubuntu 14.04":
            "ubuntu1404"
        case "Ubuntu 15.10":
            "ubuntu1510"
        case "Ubuntu 16.04":
            "ubuntu1604"
        case "Ubuntu 16.10":
            "ubuntu1610"
        case "Ubuntu 18.04":
            "ubuntu1804"
        case "Ubuntu 20.04":
            "ubuntu2004"
        case "Amazon Linux 2":
            "amazonlinux2"
        case "CentOS 8":
            "centos8"
        case "CentOS 7":
            "centos7"
        case "Windows 10":
            "win10"
        case "Ubuntu 22.04":
            "ubuntu2204"
        case "Red Hat Universal Base Image 9":
            "ubi9"
        case "Ubuntu 23.10":
            "ubuntu2310"
        case "Ubuntu 24.04":
            "ubuntu2404"
        case "Debian 12":
            "debian12"
        case "Fedora 39":
            "fedora39"
        default:
            ""
        }
    }
}

public struct SwiftOrgRelease: Codable {
    var name: String
    var platforms: [SwiftOrgPlatform]

    var stableName: String {
        let components = self.name.components(separatedBy: ".")
        if components.count == 2 {
            return self.name + ".0"
        } else {
            return self.name
        }
    }
}

public struct SwiftOrgSnapshotList: Codable {
    var aarch64: [SwiftOrgSnapshot]?
    var x86_64: [SwiftOrgSnapshot]?
    var universal: [SwiftOrgSnapshot]?
}

public struct SwiftOrgSnapshot: Codable {
    var dir: String

    private static let snapshotRegex: Regex<(Substring, Substring?, Substring?, Substring)> =
        try! Regex("swift(?:-(\\d+)\\.(\\d+))?-DEVELOPMENT-SNAPSHOT-(\\d{4}-\\d{2}-\\d{2})")

    internal func parseSnapshot() throws -> ToolchainVersion.Snapshot? {
        guard let match = try? Self.snapshotRegex.firstMatch(in: self.dir) else {
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

/// HTTPClient wrapper used for interfacing with various REST APIs and downloading things.
public struct SwiftlyHTTPClient {
    private struct Response {
        let status: HTTPResponseStatus
        let buffer: ByteBuffer
    }

    public init() {}

    /// The GitHub authentication token to use for any requests made to the GitHub API.
    public var githubToken: String?

    private func get(url: String, headers: [String: String], maxBytes: Int) async throws -> Response {
        var request = makeRequest(url: url)

        for (k, v) in headers {
            request.headers.add(name: k, value: v)
        }

        let response = try await SwiftlyCore.httpRequestExecutor.execute(request, timeout: .seconds(30))

        return Response(status: response.status, buffer: try await response.body.collect(upTo: maxBytes))
    }

    /// Decode the provided type `T` from the JSON body of the response from a GET request
    /// to the given URL.
    public func getFromJSON<T: Decodable>(
        url: String,
        type: T.Type,
        headers: [String: String] = [:]
    ) async throws -> T {
        // Maximum expected size for a JSON payload for an API is 1MB
        let response = try await self.get(url: url, headers: headers, maxBytes: 1024 * 1024)

        guard case .ok = response.status else {
            var message = "received status \"\(response.status)\" when reaching \(url)"
            let json = String(buffer: response.buffer)
            message += ": \(json)"
            throw Error(message: message)
        }

        return try JSONDecoder().decode(type.self, from: response.buffer)
    }

    /// Return an array of released Swift versions that match the given filter, up to the provided
    /// limit (default unlimited).
    public func getReleaseToolchains(
        platform: PlatformDefinition,
        arch a: String? = nil,
        limit: Int? = nil,
        filter: ((ToolchainVersion.StableRelease) -> Bool)? = nil
    ) async throws -> [ToolchainVersion.StableRelease] {
        let arch = if a == nil {
#if arch(x86_64)
            "x86_64"
#elseif arch(arm64)
            "aarch64"
#else
            #error("Unsupported processor architecture")
#endif
        } else {
            a!
        }

        let url = "https://swift.org/api/v1/install/releases.json"
        let swiftOrgReleases: [SwiftOrgRelease] = try await self.getFromJSON(url: url, type: [SwiftOrgRelease].self)

        var swiftOrgFiltered: [ToolchainVersion.StableRelease] = swiftOrgReleases.compactMap { swiftOrgRelease in
            if platform.name != "xcode" {
                // If the platform isn't xcode then verify that there is an offering for this platform name and arch
                guard let swiftOrgPlatform = swiftOrgRelease.platforms.first(where: { $0.platformName == platform.name }) else {
                    return nil
                }

                guard swiftOrgPlatform.archs.contains(arch) else {
                    return nil
                }
            }

            guard let version = try? ToolchainVersion(parsing: swiftOrgRelease.stableName),
                  case let .stable(release) = version
            else {
                return nil
            }

            if let filter {
                guard filter(release) else {
                    return nil
                }
            }

            return release
        }

        swiftOrgFiltered.sort(by: >)

        return if let limit = limit {
            Array(swiftOrgFiltered.prefix(limit))
        } else {
            swiftOrgFiltered
        }
    }

    /// Return an array of Swift snapshots that match the given filter, up to the provided
    /// limit (default unlimited).
    public func getSnapshotToolchains(
        platform: PlatformDefinition,
        arch a: String? = nil,
        branch: ToolchainVersion.Snapshot.Branch,
        limit: Int? = nil,
        filter: ((ToolchainVersion.Snapshot) -> Bool)? = nil
    ) async throws -> [ToolchainVersion.Snapshot] {
        // Fall back to using GitHub API's for snapshots on branches older than 6.0
        if case let .release(major, _) = branch, major < 6 {
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

            return try await self.mapGitHubTags(limit: limit, filterMap: filter) { page in
                try await self.getTags(page: page)
            }
        }

        let arch = if a == nil {
#if arch(x86_64)
            "x86_64"
#elseif arch(arm64)
            "aarch64"
#else
            #error("Unsupported processor architecture")
#endif
        } else {
            a!
        }

        let branchLabel = switch branch {
        case .main:
            "main"
        case let .release(major, minor):
            "\(major).\(minor)"
        }

        let platformName = if platform.name == "xcode" {
            "macos"
        } else {
            platform.name
        }

        let url = "https://swift.org/api/v1/install/dev/\(branchLabel)/\(platformName).json"

        // For a particular branch and platform the snapshots are listed underneath their architecture
        let swiftOrgSnapshotArchs: SwiftOrgSnapshotList = try await self.getFromJSON(url: url, type: SwiftOrgSnapshotList.self)

        // These are the available snapshots for the branch, platform, and architecture
        let swiftOrgSnapshots = if platform.name == "xcode" {
            swiftOrgSnapshotArchs.universal ?? [SwiftOrgSnapshot]()
        } else if arch == "aarch64" {
            swiftOrgSnapshotArchs.aarch64 ?? [SwiftOrgSnapshot]()
        } else if arch == "x86_64" {
            swiftOrgSnapshotArchs.x86_64 ?? [SwiftOrgSnapshot]()
        } else {
            [SwiftOrgSnapshot]()
        }

        // Convert these into toolchain snapshot versions that match the filter
        var matchingSnapshots = try swiftOrgSnapshots.map { try $0.parseSnapshot() }.compactMap { $0 }.filter { toolchainVersion in
            if let filter {
                guard filter(toolchainVersion) else {
                    return false
                }
            }

            return true
        }

        matchingSnapshots.sort(by: >)

        return if let limit = limit {
            Array(matchingSnapshots.prefix(limit))
        } else {
            matchingSnapshots
        }
    }

    public struct DownloadProgress {
        public let receivedBytes: Int
        public let totalBytes: Int?
    }

    public struct DownloadNotFoundError: LocalizedError {
        public let url: String
    }

    public func downloadFile(
        url: URL,
        to destination: URL,
        reportProgress: ((DownloadProgress) -> Void)? = nil
    ) async throws {
        let fileHandle = try FileHandle(forWritingTo: destination)
        defer {
            try? fileHandle.close()
        }

        let request = makeRequest(url: url.absoluteString)
        let response = try await SwiftlyCore.httpRequestExecutor.execute(request, timeout: .seconds(30))

        switch response.status {
        case .ok:
            break
        case .notFound:
            throw SwiftlyHTTPClient.DownloadNotFoundError(url: url.path)
        default:
            throw Error(message: "Received \(response.status) when trying to download \(url)")
        }

        // if defined, the content-length headers announces the size of the body
        let expectedBytes = response.headers.first(name: "content-length").flatMap(Int.init)

        var lastUpdate = Date()
        var receivedBytes = 0
        for try await buffer in response.body {
            receivedBytes += buffer.readableBytes

            try fileHandle.write(contentsOf: buffer.readableBytesView)

            let now = Date()
            if let reportProgress, lastUpdate.distance(to: now) > 0.25 || receivedBytes == expectedBytes {
                lastUpdate = now
                reportProgress(SwiftlyHTTPClient.DownloadProgress(
                    receivedBytes: receivedBytes,
                    totalBytes: expectedBytes
                ))
            }
        }

        try fileHandle.synchronize()
    }
}
