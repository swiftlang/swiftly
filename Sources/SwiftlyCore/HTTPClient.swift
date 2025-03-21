import _StringProcessing
import AsyncHTTPClient
import Foundation
import HTTPTypes
import NIO
import NIOFoundationCompat
import NIOHTTP1
import OpenAPIAsyncHTTPClient
import OpenAPIRuntime

public extension Components.Schemas.SwiftlyRelease {
    public var swiftlyVersion: SwiftlyVersion {
        get throws {
            guard let releaseVersion = try? SwiftlyVersion(parsing: self.version) else {
                throw SwiftlyError(message: "Invalid swiftly version reported: \(self.version)")
            }

            return releaseVersion
        }
    }
}

public extension Components.Schemas.SwiftlyReleasePlatformArtifacts {
    public var isDarwin: Bool {
        self.platform.value1 == .darwin
    }

    public var isLinux: Bool {
        self.platform.value1 == .linux
    }

    public var x86_64URL: URL {
        get throws {
            guard let url = URL(string: self.x8664) else {
                throw SwiftlyError(message: "The swiftly x86_64 URL is invalid: \(self.x8664)")
            }

            return url
        }
    }

    public var arm64URL: URL {
        get throws {
            guard let url = URL(string: self.arm64) else {
                throw SwiftlyError(message: "The swiftly arm64 URL is invalid: \(self.arm64)")
            }

            return url
        }
    }
}

public extension Components.Schemas.SwiftlyPlatformIdentifier {
    init(_ knownSwiftlyPlatformIdentifier: Components.Schemas.KnownSwiftlyPlatformIdentifier) {
        self.init(value1: knownSwiftlyPlatformIdentifier)
    }
}

public protocol HTTPRequestExecutor {
    func execute(_ request: HTTPClientRequest, timeout: TimeAmount) async throws -> HTTPClientResponse
    func getCurrentSwiftlyRelease() async throws -> Components.Schemas.SwiftlyRelease
    func getReleaseToolchains() async throws -> [Components.Schemas.Release]
    func getSnapshotToolchains(branch: Components.Schemas.SourceBranch, platform: Components.Schemas.PlatformIdentifier) async throws -> Components.Schemas.DevToolchains
}

internal struct SwiftlyUserAgentMiddleware: ClientMiddleware {
    package func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID _: String,
        next: (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        // Adds the `Authorization` header field with the provided value.
        request.headerFields[.userAgent] = "swiftly/\(SwiftlyCore.version)"
        return try await next(request, body, baseURL)
    }
}

/// An `HTTPRequestExecutor` backed by the shared `HTTPClient`.
internal class HTTPRequestExecutorImpl: HTTPRequestExecutor {
    let httpClient: HTTPClient

    public init() {
        var proxy: HTTPClient.Configuration.Proxy?

        func getProxyFromEnv(keys: [String]) -> HTTPClient.Configuration.Proxy? {
            let environment = ProcessInfo.processInfo.environment
            for key in keys {
                if let proxyString = environment[key],
                   let url = URL(string: proxyString),
                   let host = url.host,
                   let port = url.port
                {
                    return .server(host: host, port: port)
                }
            }
            return nil
        }

        if let httpProxy = getProxyFromEnv(keys: ["http_proxy", "HTTP_PROXY"]) {
            proxy = httpProxy
        }
        if let httpsProxy = getProxyFromEnv(keys: ["https_proxy", "HTTPS_PROXY"]) {
            proxy = httpsProxy
        }

        if proxy != nil {
            self.httpClient = HTTPClient(eventLoopGroupProvider: .singleton, configuration: HTTPClient.Configuration(proxy: proxy))
        } else {
            self.httpClient = HTTPClient.shared
        }
    }

    deinit {
        if httpClient !== HTTPClient.shared {
            try? httpClient.syncShutdown()
        }
    }

    public func execute(_ request: HTTPClientRequest, timeout: TimeAmount) async throws -> HTTPClientResponse {
        try await self.httpClient.execute(request, timeout: timeout)
    }

    public func getCurrentSwiftlyRelease() async throws -> Components.Schemas.SwiftlyRelease {
        let config = AsyncHTTPClientTransport.Configuration(client: self.httpClient, timeout: .seconds(30))
        let swiftlyUserAgent = SwiftlyUserAgentMiddleware()

        let client = Client(
            serverURL: try Servers.Server1.url(),
            transport: AsyncHTTPClientTransport(configuration: config),
            middlewares: [swiftlyUserAgent]
        )

        let response = try await client.getCurrentSwiftlyRelease()
        return try response.ok.body.json
    }

    public func getReleaseToolchains() async throws -> [Components.Schemas.Release] {
        let config = AsyncHTTPClientTransport.Configuration(client: self.httpClient, timeout: .seconds(30))
        let swiftlyUserAgent = SwiftlyUserAgentMiddleware()

        let client = Client(
            serverURL: try Servers.Server1.url(),
            transport: AsyncHTTPClientTransport(configuration: config),
            middlewares: [swiftlyUserAgent]
        )

        let response = try await client.listReleases()

        return try response.ok.body.json
    }

    public func getSnapshotToolchains(branch: Components.Schemas.SourceBranch, platform: Components.Schemas.PlatformIdentifier) async throws -> Components.Schemas.DevToolchains {
        let config = AsyncHTTPClientTransport.Configuration(client: self.httpClient, timeout: .seconds(30))
        let swiftlyUserAgent = SwiftlyUserAgentMiddleware()

        let client = Client(
            serverURL: try Servers.Server1.url(),
            transport: AsyncHTTPClientTransport(configuration: config),
            middlewares: [swiftlyUserAgent]
        )

        let response = try await client.listDevToolchains(.init(path: .init(branch: branch, platform: platform)))

        return try response.ok.body.json
    }
}

private func makeRequest(url: String) -> HTTPClientRequest {
    var request = HTTPClientRequest(url: url)
    request.headers.add(name: "User-Agent", value: "swiftly/\(SwiftlyCore.version)")
    return request
}

extension Components.Schemas.Release {
    var stableName: String {
        let components = self.name.components(separatedBy: ".")
        if components.count == 2 {
            return self.name + ".0"
        } else {
            return self.name
        }
    }
}

public extension Components.Schemas.Architecture {
    init(_ knownArchitecture: Components.Schemas.KnownArchitecture) {
        self.init(value1: knownArchitecture, value2: knownArchitecture.rawValue)
    }

    init(_ string: String) {
        self.init(value2: string)
    }
}

public extension Components.Schemas.PlatformIdentifier {
    init(_ knownPlatformIdentifier: Components.Schemas.KnownPlatformIdentifier) {
        self.init(value1: knownPlatformIdentifier)
    }

    init(_ string: String) {
        self.init(value2: string)
    }
}

public extension Components.Schemas.SourceBranch {
    init(_ knownSourceBranch: Components.Schemas.KnownSourceBranch) {
        self.init(value1: knownSourceBranch)
    }

    init(_ string: String) {
        self.init(value2: string)
    }
}

extension Components.Schemas.Architecture {
    static var x8664: Components.Schemas.Architecture = .init(Components.Schemas.KnownArchitecture.x8664)
    static var aarch64: Components.Schemas.Architecture = .init(Components.Schemas.KnownArchitecture.aarch64)
}

extension Components.Schemas.Platform {
    /// platformDef is a mapping from the 'name' field of the swift.org platform object
    /// to swiftly's PlatformDefinition, if possible.
    var platformDef: PlatformDefinition? {
        // NOTE: some of these platforms are represented on swift.org metadata, but not supported by swiftly and so they don't have constants in PlatformDefinition
        switch self.name {
        case "Ubuntu 14.04":
            PlatformDefinition(name: "ubuntu1404", nameFull: "ubuntu14.04", namePretty: "Ubuntu 14.04")
        case "Ubuntu 15.10":
            PlatformDefinition(name: "ubuntu1510", nameFull: "ubuntu15.10", namePretty: "Ubuntu 15.10")
        case "Ubuntu 16.04":
            PlatformDefinition(name: "ubuntu1604", nameFull: "ubuntu16.04", namePretty: "Ubuntu 16.04")
        case "Ubuntu 16.10":
            PlatformDefinition(name: "ubuntu1610", nameFull: "ubuntu16.10", namePretty: "Ubuntu 16.10")
        case "Ubuntu 18.04":
            PlatformDefinition(name: "ubuntu1804", nameFull: "ubuntu18.04", namePretty: "Ubuntu 18.04")
        case "Ubuntu 20.04":
            PlatformDefinition.ubuntu2004
        case "Amazon Linux 2":
            PlatformDefinition.amazonlinux2
        case "CentOS 8":
            PlatformDefinition(name: "centos8", nameFull: "centos8", namePretty: "CentOS 8")
        case "CentOS 7":
            PlatformDefinition(name: "centos7", nameFull: "centos7", namePretty: "CentOS 7")
        case "Windows 10":
            PlatformDefinition(name: "win10", nameFull: "windows10", namePretty: "Windows 10")
        case "Ubuntu 22.04":
            PlatformDefinition.ubuntu2204
        case "Red Hat Universal Base Image 9":
            PlatformDefinition.rhel9
        case "Ubuntu 24.04":
            PlatformDefinition(name: "ubuntu2404", nameFull: "ubuntu24.04", namePretty: "Ubuntu 24.04")
        case "Debian 12":
            PlatformDefinition(name: "debian12", nameFull: "debian12", namePretty: "Debian GNU/Linux 12")
        case "Fedora 39":
            PlatformDefinition(name: "fedora39", nameFull: "fedora39", namePretty: "Fedora Linux 39")
        default:
            nil
        }
    }

    func matches(_ platform: PlatformDefinition) -> Bool {
        guard let myPlatform = self.platformDef else {
            return false
        }

        return myPlatform.name == platform.name
    }
}

extension Components.Schemas.DevToolchainForArch {
    private static let snapshotRegex: Regex<(Substring, Substring?, Substring?, Substring)> =
        try! Regex("swift(?:-(\\d+)\\.(\\d+))?-DEVELOPMENT-SNAPSHOT-(\\d{4}-\\d{2}-\\d{2})")

    internal func parseSnapshot() throws -> ToolchainVersion.Snapshot? {
        guard let match = try? Self.snapshotRegex.firstMatch(in: self.dir) else {
            return nil
        }

        let branch: ToolchainVersion.Snapshot.Branch
        if let majorString = match.output.1, let minorString = match.output.2 {
            guard let major = Int(majorString), let minor = Int(minorString) else {
                throw SwiftlyError(message: "malformatted release branch: \"\(majorString).\(minorString)\"")
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

    private func get(url: String, headers: [String: String], maxBytes: Int) async throws -> Response {
        var request = makeRequest(url: url)

        for (k, v) in headers {
            request.headers.add(name: k, value: v)
        }

        let response = try await SwiftlyCore.httpRequestExecutor.execute(request, timeout: .seconds(30))

        return Response(status: response.status, buffer: try await response.body.collect(upTo: maxBytes))
    }

    public struct JSONNotFoundError: LocalizedError {
        public var url: String
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

        switch response.status {
        case .ok:
            break
        case .notFound:
            throw SwiftlyHTTPClient.JSONNotFoundError(url: url)
        default:
            let json = String(buffer: response.buffer)
            throw SwiftlyError(message: "Received \(response.status) when reaching \(url) for JSON: \(json)")
        }

        return try JSONDecoder().decode(type.self, from: response.buffer)
    }

    /// Return the current Swiftly release using the swift.org API.
    public func getCurrentSwiftlyRelease() async throws -> Components.Schemas.SwiftlyRelease {
        try await SwiftlyCore.httpRequestExecutor.getCurrentSwiftlyRelease()
    }

    /// Return an array of released Swift versions that match the given filter, up to the provided
    /// limit (default unlimited).
    public func getReleaseToolchains(
        platform: PlatformDefinition,
        arch a: Components.Schemas.Architecture? = nil,
        limit: Int? = nil,
        filter: ((ToolchainVersion.StableRelease) -> Bool)? = nil
    ) async throws -> [ToolchainVersion.StableRelease] {
        let arch = a ?? cpuArch

        let releases = try await SwiftlyCore.httpRequestExecutor.getReleaseToolchains()

        var swiftOrgFiltered: [ToolchainVersion.StableRelease] = try releases.compactMap { swiftOrgRelease in
            if platform.name != PlatformDefinition.macOS.name {
                // If the platform isn't xcode then verify that there is an offering for this platform name and arch
                guard let swiftOrgPlatform = swiftOrgRelease.platforms.first(where: { $0.matches(platform) }) else {
                    return nil
                }

                guard case let archs = swiftOrgPlatform.archs, archs.contains(arch) else {
                    return nil
                }
            }

            guard let version = try? ToolchainVersion(parsing: swiftOrgRelease.stableName),
                  case let .stable(release) = version
            else {
                throw SwiftlyError(message: "error parsing swift.org release version: \(swiftOrgRelease.stableName)")
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

    public struct SnapshotBranchNotFoundError: LocalizedError {
        public var branch: ToolchainVersion.Snapshot.Branch
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
        let platformId: Components.Schemas.PlatformIdentifier = switch platform.name {
        // These are new platforms that aren't yet in the list of known platforms in the OpenAPI schema
        case PlatformDefinition.ubuntu2404.name, PlatformDefinition.debian12.name, PlatformDefinition.fedora39.name:
            .init(platform.name)

        case PlatformDefinition.ubuntu2204.name:
            .init(.ubuntu2204)
        case PlatformDefinition.ubuntu2004.name:
            .init(.ubuntu2004)
        case PlatformDefinition.rhel9.name:
            .init(.ubi9)
        case PlatformDefinition.amazonlinux2.name:
            .init(.amazonlinux2)
        case PlatformDefinition.macOS.name:
            .init(.macos)
        default:
            throw SwiftlyError(message: "No snapshot toolchains available for platform \(platform.name)")
        }

        let sourceBranch: Components.Schemas.SourceBranch = switch branch {
        case .main:
            .init(.main)
        case let .release(major, minor):
            .init("\(major).\(minor)")
        }

        let devToolchains = try await SwiftlyCore.httpRequestExecutor.getSnapshotToolchains(branch: sourceBranch, platform: platformId)

        let arch = a ?? cpuArch.value2

        // These are the available snapshots for the branch, platform, and architecture
        let swiftOrgSnapshots = if platform.name == PlatformDefinition.macOS.name {
            devToolchains.universal ?? [Components.Schemas.DevToolchainForArch]()
        } else if arch == "aarch64" {
            devToolchains.aarch64 ?? [Components.Schemas.DevToolchainForArch]()
        } else if arch == "x86_64" {
            devToolchains.x8664 ?? [Components.Schemas.DevToolchainForArch]()
        } else {
            [Components.Schemas.DevToolchainForArch]()
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
            throw SwiftlyError(message: "Received \(response.status) when trying to download \(url)")
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
