import _StringProcessing
import AsyncHTTPClient
import Foundation
import HTTPTypes
import NIO
import NIOFoundationCompat
import NIOHTTP1
import OpenAPIAsyncHTTPClient
import OpenAPIRuntime
import SwiftlyDownloadAPI
import SwiftlyWebsiteAPI

extension SwiftlyWebsiteAPI.Components.Schemas.SwiftlyRelease {
    public var swiftlyVersion: SwiftlyVersion {
        get throws {
            guard let releaseVersion = try? SwiftlyVersion(parsing: self.version) else {
                throw SwiftlyError(message: "Invalid swiftly version reported: \(self.version)")
            }

            return releaseVersion
        }
    }
}

extension SwiftlyWebsiteAPI.Components.Schemas.SwiftlyReleasePlatformArtifacts {
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

extension SwiftlyWebsiteAPI.Components.Schemas.SwiftlyPlatformIdentifier {
    public init(_ knownSwiftlyPlatformIdentifier: SwiftlyWebsiteAPI.Components.Schemas.KnownSwiftlyPlatformIdentifier) {
        self.init(value1: knownSwiftlyPlatformIdentifier)
    }
}

public struct ToolchainFile: Sendable {
    public var category: String
    public var platform: String
    public var version: String
    public var file: String

    public init(category: String, platform: String, version: String, file: String) {
        self.category = category
        self.platform = platform
        self.version = version
        self.file = file
    }
}

public protocol HTTPRequestExecutor: Sendable {
    func getCurrentSwiftlyRelease() async throws -> SwiftlyWebsiteAPI.Components.Schemas.SwiftlyRelease
    func getReleaseToolchains() async throws -> [SwiftlyWebsiteAPI.Components.Schemas.Release]
    func getSnapshotToolchains(
        branch: SwiftlyWebsiteAPI.Components.Schemas.SourceBranch, platform: SwiftlyWebsiteAPI.Components.Schemas.PlatformIdentifier
    ) async throws -> SwiftlyWebsiteAPI.Components.Schemas.DevToolchains
    func getGpgKeys() async throws -> OpenAPIRuntime.HTTPBody
    func getSwiftlyRelease(url: URL) async throws -> OpenAPIRuntime.HTTPBody
    func getSwiftlyReleaseSignature(url: URL) async throws -> OpenAPIRuntime.HTTPBody
    func getSwiftToolchainFile(_ toolchainFile: ToolchainFile) async throws -> OpenAPIRuntime.HTTPBody
    func getSwiftToolchainFileSignature(_ toolchainFile: ToolchainFile) async throws
        -> OpenAPIRuntime.HTTPBody
}

struct SwiftlyUserAgentMiddleware: ClientMiddleware {
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

/// An `HTTPRequestExecutor` backed by a shared `HTTPClient`. This makes actual network requests.
public final class HTTPRequestExecutorImpl: HTTPRequestExecutor {
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
            self.httpClient = HTTPClient(
                eventLoopGroupProvider: .singleton, configuration: HTTPClient.Configuration(proxy: proxy)
            )
        } else {
            self.httpClient = HTTPClient.shared
        }
    }

    deinit {
        if httpClient !== HTTPClient.shared {
            try? httpClient.syncShutdown()
        }
    }

    private func websiteClient() throws -> SwiftlyWebsiteAPI.Client {
        let swiftlyUserAgent = SwiftlyUserAgentMiddleware()
        let transport: ClientTransport

        let config = AsyncHTTPClientTransport.Configuration(
            client: self.httpClient, timeout: .seconds(30)
        )
        transport = AsyncHTTPClientTransport(configuration: config)

        return Client(
            serverURL: try SwiftlyWebsiteAPI.Servers.productionURL(),
            transport: transport,
            middlewares: [swiftlyUserAgent]
        )
    }

    private func downloadClient(baseURL: URL) throws -> SwiftlyDownloadAPI.Client {
        let swiftlyUserAgent = SwiftlyUserAgentMiddleware()
        let transport: ClientTransport

        let config = AsyncHTTPClientTransport.Configuration(
            client: self.httpClient, timeout: .seconds(30)
        )
        transport = AsyncHTTPClientTransport(configuration: config)

        return SwiftlyDownloadAPI.Client(
            serverURL: baseURL,
            transport: transport,
            middlewares: [swiftlyUserAgent]
        )
    }

    public func getCurrentSwiftlyRelease() async throws -> SwiftlyWebsiteAPI.Components.Schemas.SwiftlyRelease {
        let response = try await self.websiteClient().getCurrentSwiftlyRelease()
        return try response.ok.body.json
    }

    public func getReleaseToolchains() async throws -> [SwiftlyWebsiteAPI.Components.Schemas.Release] {
        let response = try await self.websiteClient().listReleases()
        return try response.ok.body.json
    }

    public func getSnapshotToolchains(
        branch: SwiftlyWebsiteAPI.Components.Schemas.SourceBranch, platform: SwiftlyWebsiteAPI.Components.Schemas.PlatformIdentifier
    ) async throws -> SwiftlyWebsiteAPI.Components.Schemas.DevToolchains {
        let response = try await self.websiteClient().listDevToolchains(
            .init(path: .init(branch: branch, platform: platform)))
        return try response.ok.body.json
    }

    public func getGpgKeys() async throws -> OpenAPIRuntime.HTTPBody {
        let response = try await downloadClient(baseURL: SwiftlyDownloadAPI.Servers.productionURL()).swiftGpgKeys(
            .init())

        return try response.ok.body.plainText
    }

    public func getSwiftlyRelease(url: URL) async throws -> OpenAPIRuntime.HTTPBody {
        guard try url.host(percentEncoded: false) == Servers.productionDownloadURL().host(percentEncoded: false),
              let match = try #/\/swiftly\/(?<platform>.+)\/(?<file>.+)/#.wholeMatch(
                  in: url.path(percentEncoded: false))
        else {
            throw SwiftlyError(message: "Unexpected Swiftly download URL format: \(url.path(percentEncoded: false))")
        }

        let response = try await downloadClient(baseURL: SwiftlyDownloadAPI.Servers.productionDownloadURL())
            .downloadSwiftlyRelease(
                .init(path: .init(platform: String(match.output.platform), file: String(match.output.file)))
            )

        return try response.ok.body.binary
    }

    public func getSwiftlyReleaseSignature(url: URL) async throws -> OpenAPIRuntime.HTTPBody {
        guard try url.host(percentEncoded: false) == Servers.productionDownloadURL().host(percentEncoded: false),
              let match = try #/\/swiftly\/(?<platform>.+)\/(?<file>.+).sig/#.wholeMatch(
                  in: url.path(percentEncoded: false))
        else {
            throw SwiftlyError(message: "Unexpected Swiftly signature URL format: \(url.path(percentEncoded: false))")
        }

        let response = try await downloadClient(baseURL: SwiftlyDownloadAPI.Servers.productionDownloadURL())
            .getSwiftlyReleaseSignature(
                .init(path: .init(platform: String(match.output.platform), file: String(match.output.file)))
            )

        return try response.ok.body.binary
    }

    public func getSwiftToolchainFile(_ toolchainFile: ToolchainFile) async throws
        -> OpenAPIRuntime.HTTPBody
    {
        let response = try await downloadClient(baseURL: SwiftlyDownloadAPI.Servers.productionDownloadURL())
            .downloadSwiftToolchain(
                .init(
                    path: .init(
                        category: String(toolchainFile.category), platform: String(toolchainFile.platform),
                        version: String(toolchainFile.version), file: String(toolchainFile.file)
                    )))
        if response == .notFound {
            throw try DownloadNotFoundError(
                url: Servers.productionDownloadURL().appendingPathComponent(toolchainFile.category).appendingPathComponent(toolchainFile.platform).appendingPathComponent(toolchainFile.version).appendingPathComponent(toolchainFile.file))
        }

        return try response.ok.body.binary
    }

    public func getSwiftToolchainFileSignature(_ toolchainFile: ToolchainFile) async throws
        -> OpenAPIRuntime.HTTPBody
    {
        let response = try await downloadClient(baseURL: SwiftlyDownloadAPI.Servers.productionDownloadURL())
            .getSwiftToolchainSignature(
                .init(
                    path: .init(
                        category: String(toolchainFile.category), platform: String(toolchainFile.platform),
                        version: String(toolchainFile.version), file: String(toolchainFile.file)
                    )))

        return try response.ok.body.binary
    }
}

extension SwiftlyWebsiteAPI.Components.Schemas.Release {
    var stableName: String {
        let components = self.name.components(separatedBy: ".")
        if components.count == 2 {
            return self.name + ".0"
        } else {
            return self.name
        }
    }
}

extension SwiftlyWebsiteAPI.Components.Schemas.Architecture {
    public init(_ knownArchitecture: SwiftlyWebsiteAPI.Components.Schemas.KnownArchitecture) {
        self.init(value1: knownArchitecture, value2: knownArchitecture.rawValue)
    }

    public init(_ string: String) {
        self.init(value2: string)
    }
}

extension SwiftlyWebsiteAPI.Components.Schemas.PlatformIdentifier {
    public init(_ knownPlatformIdentifier: SwiftlyWebsiteAPI.Components.Schemas.KnownPlatformIdentifier) {
        self.init(value1: knownPlatformIdentifier)
    }

    public init(_ string: String) {
        self.init(value2: string)
    }
}

extension SwiftlyWebsiteAPI.Components.Schemas.SourceBranch {
    public init(_ knownSourceBranch: SwiftlyWebsiteAPI.Components.Schemas.KnownSourceBranch) {
        self.init(value1: knownSourceBranch)
    }

    public init(_ string: String) {
        self.init(value2: string)
    }
}

extension SwiftlyWebsiteAPI.Components.Schemas.Architecture {
    static let x8664: SwiftlyWebsiteAPI.Components.Schemas.Architecture = .init(
        SwiftlyWebsiteAPI.Components.Schemas.KnownArchitecture.x8664)
    static let aarch64: SwiftlyWebsiteAPI.Components.Schemas.Architecture = .init(
        SwiftlyWebsiteAPI.Components.Schemas.KnownArchitecture.aarch64)
}

extension SwiftlyWebsiteAPI.Components.Schemas.Platform {
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

extension SwiftlyWebsiteAPI.Components.Schemas.DevToolchainForArch {
    private static func snapshotRegex() -> Regex<(Substring, Substring?, Substring?, Substring)> {
        try! Regex("swift(?:-(\\d+)\\.(\\d+))?-DEVELOPMENT-SNAPSHOT-(\\d{4}-\\d{2}-\\d{2})")
    }

    func parseSnapshot() throws -> ToolchainVersion.Snapshot? {
        guard let match = try? Self.snapshotRegex().firstMatch(in: self.dir) else {
            return nil
        }

        let branch: ToolchainVersion.Snapshot.Branch
        if let majorString = match.output.1, let minorString = match.output.2 {
            guard let major = Int(majorString), let minor = Int(minorString) else {
                throw SwiftlyError(
                    message: "malformatted release branch: \"\(majorString).\(minorString)\"")
            }
            branch = .release(major: major, minor: minor)
        } else {
            branch = .main
        }

        return ToolchainVersion.Snapshot(branch: branch, date: String(match.output.3))
    }
}

public struct DownloadProgress {
    public let receivedBytes: Int
    public let totalBytes: Int?
}

public struct DownloadNotFoundError: LocalizedError {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }
}

/// HTTPClient wrapper used for interfacing with various REST APIs and downloading things.
public struct SwiftlyHTTPClient: Sendable {
    public let httpRequestExecutor: HTTPRequestExecutor

    public init(httpRequestExecutor: HTTPRequestExecutor) {
        self.httpRequestExecutor = httpRequestExecutor
    }

    /// Return the current Swiftly release using the swift.org API.
    public func getCurrentSwiftlyRelease() async throws -> SwiftlyWebsiteAPI.Components.Schemas.SwiftlyRelease {
        try await self.httpRequestExecutor.getCurrentSwiftlyRelease()
    }

    /// Return an array of released Swift versions that match the given filter, up to the provided
    /// limit (default unlimited).
    public func getReleaseToolchains(
        platform: PlatformDefinition,
        arch a: SwiftlyWebsiteAPI.Components.Schemas.Architecture? = nil,
        limit: Int? = nil,
        filter: ((ToolchainVersion.StableRelease) -> Bool)? = nil
    ) async throws -> [ToolchainVersion.StableRelease] {
        let arch = a ?? cpuArch

        let releases = try await self.httpRequestExecutor.getReleaseToolchains()

        var swiftOrgFiltered: [ToolchainVersion.StableRelease] = try releases.compactMap {
            swiftOrgRelease in
            if platform.name != PlatformDefinition.macOS.name {
                // If the platform isn't xcode then verify that there is an offering for this platform name and arch
                guard
                    let swiftOrgPlatform = swiftOrgRelease.platforms.first(where: { $0.matches(platform) })
                else {
                    return nil
                }

                guard case let archs = swiftOrgPlatform.archs, archs.contains(arch) else {
                    return nil
                }
            }

            guard let version = try? ToolchainVersion(parsing: swiftOrgRelease.stableName),
                  case let .stable(release) = version
            else {
                throw SwiftlyError(
                    message: "error parsing swift.org release version: \(swiftOrgRelease.stableName)")
            }

            if let filter {
                guard filter(release) else {
                    return nil
                }
            }

            return release
        }

        swiftOrgFiltered.sort(by: >)

        return if let limit {
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
        let platformId: SwiftlyWebsiteAPI.Components.Schemas.PlatformIdentifier =
            switch platform.name
        {
        // These are new platforms that aren't yet in the list of known platforms in the OpenAPI schema
        case PlatformDefinition.ubuntu2404.name, PlatformDefinition.debian12.name,
             PlatformDefinition.fedora39.name:
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
            throw SwiftlyError(
                message: "No snapshot toolchains available for platform \(platform.name)")
        }

        let sourceBranch: SwiftlyWebsiteAPI.Components.Schemas.SourceBranch =
            switch branch
        {
        case .main:
            .init(.main)
        case let .release(major, minor):
            .init("\(major).\(minor)")
        }

        let devToolchains = try await self.httpRequestExecutor.getSnapshotToolchains(
            branch: sourceBranch, platform: platformId
        )

        let arch = a ?? cpuArch.value2

        // These are the available snapshots for the branch, platform, and architecture
        let swiftOrgSnapshots =
            if platform.name == PlatformDefinition.macOS.name
        {
            devToolchains.universal ?? [SwiftlyWebsiteAPI.Components.Schemas.DevToolchainForArch]()
        } else if arch == "aarch64" {
            devToolchains.aarch64 ?? [SwiftlyWebsiteAPI.Components.Schemas.DevToolchainForArch]()
        } else if arch == "x86_64" {
            devToolchains.x8664 ?? [SwiftlyWebsiteAPI.Components.Schemas.DevToolchainForArch]()
        } else {
            [SwiftlyWebsiteAPI.Components.Schemas.DevToolchainForArch]()
        }

        // Convert these into toolchain snapshot versions that match the filter
        var matchingSnapshots = try swiftOrgSnapshots.map { try $0.parseSnapshot() }.compactMap { $0 }
            .filter { toolchainVersion in
                if let filter {
                    guard filter(toolchainVersion) else {
                        return false
                    }
                }

                return true
            }

        matchingSnapshots.sort(by: >)

        return if let limit {
            Array(matchingSnapshots.prefix(limit))
        } else {
            matchingSnapshots
        }
    }

    public func getGpgKeys() async throws -> OpenAPIRuntime.HTTPBody {
        try await self.httpRequestExecutor.getGpgKeys()
    }

    public func getSwiftlyRelease(url: URL) async throws -> OpenAPIRuntime.HTTPBody {
        try await self.httpRequestExecutor.getSwiftlyRelease(url: url)
    }

    public func getSwiftlyReleaseSignature(url: URL) async throws -> OpenAPIRuntime.HTTPBody {
        try await self.httpRequestExecutor.getSwiftlyReleaseSignature(url: url)
    }

    public func getSwiftToolchainFile(_ toolchainFile: ToolchainFile) async throws
        -> OpenAPIRuntime.HTTPBody
    {
        try await self.httpRequestExecutor.getSwiftToolchainFile(toolchainFile)
    }

    public func getSwiftToolchainFileSignature(_ toolchainFile: ToolchainFile) async throws
        -> OpenAPIRuntime.HTTPBody
    {
        try await self.httpRequestExecutor.getSwiftToolchainFileSignature(toolchainFile)
    }
}

extension OpenAPIRuntime.HTTPBody {
    public func download(to destination: URL, reportProgress: ((DownloadProgress) -> Void)? = nil)
        async throws
    {
        let fileHandle = try FileHandle(forWritingTo: destination)
        defer {
            try? fileHandle.close()
        }

        let expectedBytes: Int?
        switch self.length {
        case .unknown:
            expectedBytes = nil
        case let .known(count):
            expectedBytes = Int(count)
        }

        var lastUpdate = Date()
        var receivedBytes = 0
        for try await buffer in self {
            receivedBytes += buffer.count

            try fileHandle.write(contentsOf: buffer)

            let now = Date()
            if let reportProgress, lastUpdate.distance(to: now) > 0.25 || receivedBytes == expectedBytes {
                lastUpdate = now
                reportProgress(
                    DownloadProgress(
                        receivedBytes: receivedBytes,
                        totalBytes: expectedBytes
                    ))
            }
        }

        try fileHandle.synchronize()
    }
}
