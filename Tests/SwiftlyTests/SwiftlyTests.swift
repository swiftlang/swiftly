import _StringProcessing
import ArgumentParser
import AsyncHTTPClient
import Foundation
import NIO
@testable import Swiftly
@testable import SwiftlyCore
import Testing

#if os(macOS)
import MacOSPlatform
#endif

import AsyncHTTPClient
import NIO

struct SwiftlyTestError: LocalizedError {
    let message: String
}

let unmockedMsg = "All swiftly test case logic must be mocked in order to prevent mutation of the system running the test. This test must either run swiftly components inside a SwiftlyTests.with... closure, or it must have one of the @Test traits, such as @Test(.testHome), or @Test(.mock...)"

struct OutputHandlerFail: OutputHandler {
    func handleOutputLine(_: String) {
        fatalError(unmockedMsg)
    }
}

struct InputProviderFail: InputProvider {
    func readLine() -> String? {
        fatalError(unmockedMsg)
    }
}

struct HTTPRequestExecutorFail: HTTPRequestExecutor {
    func execute(_: HTTPClientRequest, timeout _: TimeAmount) async throws -> HTTPClientResponse { fatalError(unmockedMsg) }
    func getCurrentSwiftlyRelease() async throws -> Components.Schemas.SwiftlyRelease { fatalError(unmockedMsg) }
    func getReleaseToolchains() async throws -> [Components.Schemas.Release] { fatalError(unmockedMsg) }
    func getSnapshotToolchains(branch _: Components.Schemas.SourceBranch, platform _: Components.Schemas.PlatformIdentifier) async throws -> Components.Schemas.DevToolchains { fatalError(unmockedMsg) }
}

// Convenience extensions to common Swiftly and SwiftlyCore types to set the correct context

extension Config {
    public static func load() throws -> Config {
        try Config.load(SwiftlyTests.ctx)
    }

    public func save() throws {
        try self.save(SwiftlyTests.ctx)
    }
}

extension SwiftlyCoreContext {
    public init(
        mockedHomeDir: URL?,
        httpRequestExecutor: HTTPRequestExecutor,
        outputHandler: (any OutputHandler)?,
        inputProvider: (any InputProvider)?
    ) {
        self.init()

        self.mockedHomeDir = mockedHomeDir
        self.currentDirectory = mockedHomeDir ?? URL.currentDirectory()
        self.httpClient = SwiftlyHTTPClient(httpRequestExecutor: httpRequestExecutor)
        self.outputHandler = outputHandler
        self.inputProvider = inputProvider
    }
}

// Convenience test scoping traits

struct TestHomeTrait: TestTrait, TestScoping {
    var name: String = "testHome"

    init(_ name: String) { self.name = name }

    func provideScope(for _: Test, testCase _: Test.Case?, performing function: @Sendable () async throws -> Void) async throws {
        try await SwiftlyTests.withTestHome(name: self.name) {
            try await function()
        }
    }
}

extension Trait where Self == TestHomeTrait {
    /// Run the test with a test home directory.
    static func testHome(_ name: String = "testHome") -> Self { Self(name) }
}

struct MockHomeToolchainsTrait: TestTrait, TestScoping {
    var name: String = "testHome"
    var toolchains: Set<ToolchainVersion> = SwiftlyTests.allToolchains

    init(_ name: String, toolchains: Set<ToolchainVersion>) {
        self.name = name
        self.toolchains = toolchains
    }

    func provideScope(for _: Test, testCase _: Test.Case?, performing function: @Sendable () async throws -> Void) async throws {
        try await SwiftlyTests.withMockedHome(homeName: self.name, toolchains: self.toolchains) {
            try await function()
        }
    }
}

extension Trait where Self == MockHomeToolchainsTrait {
    /// Run the test with this trait to get a mocked home directory with a predefined collection of toolchains already installed.
    static func mockHomeToolchains(_ homeName: String = "testHome", toolchains: Set<ToolchainVersion> = SwiftlyTests.allToolchains) -> Self { Self(homeName, toolchains: toolchains) }
}

struct TestHomeMockedToolchainTrait: TestTrait, TestScoping {
    var name: String = "testHome"

    init(_ name: String) { self.name = name }

    func provideScope(for _: Test, testCase _: Test.Case?, performing function: @Sendable () async throws -> Void) async throws {
        try await SwiftlyTests.withTestHome(name: self.name) {
            try await SwiftlyTests.withMockedToolchain {
                try await function()
            }
        }
    }
}

extension Trait where Self == TestHomeMockedToolchainTrait {
    /// Run the test with this trait to get a test home directory and a mocked
    /// toolchain can be installed by request, at any version.
    static func testHomeMockedToolchain(_ name: String = "testHome") -> Self { Self(name) }
}

public enum SwiftlyTests {
    @TaskLocal static var ctx: SwiftlyCoreContext = .init(
        mockedHomeDir: URL(fileURLWithPath: "/does/not/exist"),
        httpRequestExecutor: HTTPRequestExecutorFail(),
        outputHandler: OutputHandlerFail(),
        inputProvider: InputProviderFail()
    )

    // Below are some constants that can be used to write test cases.
    public static let oldStable = ToolchainVersion(major: 5, minor: 6, patch: 0)
    public static let oldStableNewPatch = ToolchainVersion(major: 5, minor: 6, patch: 3)
    public static let newStable = ToolchainVersion(major: 5, minor: 7, patch: 0)
    public static let oldMainSnapshot = ToolchainVersion(snapshotBranch: .main, date: "2025-03-10")
    public static let newMainSnapshot = ToolchainVersion(snapshotBranch: .main, date: "2025-03-14")
    public static let oldReleaseSnapshot = ToolchainVersion(snapshotBranch: .release(major: 6, minor: 0), date: "2025-02-09")
    public static let newReleaseSnapshot = ToolchainVersion(snapshotBranch: .release(major: 6, minor: 0), date: "2025-02-11")

    static let allToolchains: Set<ToolchainVersion> = [
        oldStable,
        oldStableNewPatch,
        newStable,
        oldMainSnapshot,
        newMainSnapshot,
        oldReleaseSnapshot,
        newReleaseSnapshot,
    ]

    static func baseTestConfig() async throws -> Config {
        guard let pd = try? await Swiftly.currentPlatform.detectPlatform(Self.ctx, disableConfirmation: true, platform: nil) else {
            throw SwiftlyTestError(message: "Unable to detect the current platform.")
        }

        return Config(
            inUse: nil,
            installedToolchains: [],
            platform: pd
        )
    }

    static func runCommand<T: SwiftlyCommand>(_ commandType: T.Type, _ arguments: [String]) async throws {
        let rawCmd = try Swiftly.parseAsRoot(arguments)

        guard var cmd = rawCmd as? T else {
            throw SwiftlyTestError(
                message: "expected \(arguments) to parse as \(commandType) but got \(rawCmd) instead"
            )
        }

        try await cmd.run(Self.ctx)
    }

    /// Run this command, using the provided input as the stdin (in lines). Returns an array of captured
    /// output lines.
    static func runWithMockedIO<T: SwiftlyCommand>(_ commandType: T.Type, _ arguments: [String], quiet: Bool = false, input: [String]? = nil) async throws -> [String] {
        let handler = TestOutputHandler(quiet: quiet)
        let provider: (any InputProvider)? = if let input {
            TestInputProvider(lines: input)
        } else {
            nil
        }

        let ctx = SwiftlyCoreContext(
            mockedHomeDir: SwiftlyTests.ctx.mockedHomeDir,
            httpRequestExecutor: SwiftlyTests.ctx.httpClient.httpRequestExecutor,
            outputHandler: handler,
            inputProvider: provider
        )

        let rawCmd = try Swiftly.parseAsRoot(arguments)

        guard var cmd = rawCmd as? T else {
            throw SwiftlyTestError(
                message: "expected \(arguments) to parse as \(commandType) but got \(rawCmd) instead"
            )
        }

        try await cmd.run(ctx)

        return handler.lines
    }

    static func getTestHomePath(name: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("swiftly-tests-\(name)-\(UUID())")
    }

    /// Create a fresh swiftly home directory, populate it with a base config, and run the provided closure.
    /// Any swiftly commands executed in the closure will use this new home directory.
    ///
    /// The home directory will be deleted after the provided closure has been executed.
    static func withTestHome(
        name: String = "testHome",
        _ f: () async throws -> Void
    ) async throws {
        let testHome = Self.getTestHomePath(name: name)

        defer {
            try? testHome.deleteIfExists()
        }

        let ctx = SwiftlyCoreContext(
            mockedHomeDir: testHome,
            httpRequestExecutor: SwiftlyTests.ctx.httpClient.httpRequestExecutor,
            outputHandler: nil,
            inputProvider: nil
        )

        for dir in Swiftly.requiredDirectories(ctx) {
            try dir.deleteIfExists()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: false)
        }

        let config = try await Self.baseTestConfig()
        try config.save(ctx)

        try await Self.$ctx.withValue(ctx) {
            try await f()
        }
    }

    /// Creates a mocked home directory with the supplied toolchains pre-installed as mocks,
    /// and the provided inUse is the global default toolchain.
    static func withMockedHome(
        homeName: String,
        toolchains: Set<ToolchainVersion>,
        inUse: ToolchainVersion? = nil,
        f: () async throws -> Void
    ) async throws {
        try await Self.withTestHome(name: homeName) {
            for toolchain in toolchains {
                try await Self.installMockedToolchain(toolchain: toolchain)
            }

            if !toolchains.isEmpty {
                try await Self.runCommand(Use.self, ["use", inUse?.name ?? "latest"])
            } else {
                try FileManager.default.createDirectory(
                    at: Swiftly.currentPlatform.swiftlyBinDir(Self.ctx),
                    withIntermediateDirectories: true
                )
            }

            try await f()
        }
    }

    /// Operate with a mocked swiftly version available when requested with the HTTP request executor.
    static func withMockedSwiftlyVersion(latestSwiftlyVersion: SwiftlyVersion = SwiftlyCore.version, _ f: () async throws -> Void) async throws {
        let mockDownloader = MockToolchainDownloader(executables: ["swift"], latestSwiftlyVersion: latestSwiftlyVersion)

        let ctx = SwiftlyCoreContext(
            mockedHomeDir: SwiftlyTests.ctx.mockedHomeDir,
            httpRequestExecutor: mockDownloader,
            outputHandler: SwiftlyTests.ctx.outputHandler,
            inputProvider: SwiftlyTests.ctx.inputProvider
        )

        try await SwiftlyTests.$ctx.withValue(ctx) {
            try await f()
        }
    }

    /// Operate with a mocked toolchain that has the provided list of executables in its bin directory.
    static func withMockedToolchain(executables: [String]? = nil, f: () async throws -> Void) async throws {
        let mockDownloader = MockToolchainDownloader(executables: executables)

        let ctx = SwiftlyCoreContext(
            mockedHomeDir: SwiftlyTests.ctx.mockedHomeDir,
            httpRequestExecutor: mockDownloader,
            outputHandler: SwiftlyTests.ctx.outputHandler,
            inputProvider: SwiftlyTests.ctx.inputProvider
        )

        try await SwiftlyTests.$ctx.withValue(ctx) {
            try await f()
        }
    }

    /// Validates that the provided toolchain is the one currently marked as "in use", both by checking the
    /// configuration file and by executing `swift --version` using the swift executable in the `bin` directory.
    /// If nil is provided, this validates that no toolchain is currently in use.
    static func validateInUse(expected: ToolchainVersion?) async throws {
        let config = try Config.load()
        #expect(config.inUse == expected)
    }

    /// Validate that all of the provided toolchains have been installed.
    ///
    /// This method ensures that config.json reflects the expected installed toolchains and also
    /// validates that the toolchains on disk match their expected versions via `swift --version`.
    static func validateInstalledToolchains(_ toolchains: Set<ToolchainVersion>, description: String) async throws {
        let config = try Config.load()

        guard config.installedToolchains == toolchains else {
            throw SwiftlyTestError(message: "\(description): expected \(toolchains) but got \(config.installedToolchains)")
        }

#if os(macOS)
        for toolchain in toolchains {
            let toolchainDir = Self.ctx.mockedHomeDir!.appendingPathComponent("Toolchains/\(toolchain.identifier).xctoolchain")
            #expect(toolchainDir.fileExists())

            let swiftBinary = toolchainDir
                .appendingPathComponent("usr")
                .appendingPathComponent("bin")
                .appendingPathComponent("swift")

            let executable = SwiftExecutable(path: swiftBinary)
            let actualVersion = try await executable.version()
            #expect(actualVersion == toolchain)
        }
#elseif os(Linux)
        // Verify that the toolchains on disk correspond to those in the config.
        for toolchain in toolchains {
            let toolchainDir = Swiftly.currentPlatform.swiftlyHomeDir(Self.ctx)
                .appendingPathComponent("toolchains/\(toolchain.name)")
            #expect(toolchainDir.fileExists())

            let swiftBinary = toolchainDir
                .appendingPathComponent("usr")
                .appendingPathComponent("bin")
                .appendingPathComponent("swift")

            let executable = SwiftExecutable(path: swiftBinary)
            let actualVersion = try await executable.version()
            #expect(actualVersion == toolchain)
        }
#endif
    }

    /// Install a mocked toolchain according to the provided selector that includes the provided list of executables
    /// in its bin directory.
    ///
    /// When executed, the mocked executables will simply print the toolchain version and return.
    static func installMockedToolchain(selector: String, args: [String] = [], executables: [String]? = nil) async throws {
        try await Self.withMockedToolchain(executables: executables) {
            try await Self.runCommand(Install.self, ["install", "\(selector)", "--no-verify", "--post-install-file=\(Swiftly.currentPlatform.getTempFilePath().path)"] + args)
        }
    }

    /// Install a mocked toolchain according to the provided selector that includes the provided list of executables
    /// in its bin directory.
    ///
    /// When executed, the mocked executables will simply print the toolchain version and return.
    static func installMockedToolchain(toolchain: ToolchainVersion, executables: [String]? = nil) async throws {
        try await Self.installMockedToolchain(selector: "\(toolchain.name)", executables: executables)
    }

    /// Install a mocked toolchain associated with the given version that includes the provided list of executables
    /// in its bin directory.
    ///
    /// When executed, the mocked executables will simply print the toolchain version and return.
    static func installMockedToolchain(selector: ToolchainSelector, executables: [String]? = nil) async throws {
        try await Self.installMockedToolchain(selector: "\(selector)", executables: executables)
    }

    /// Get the toolchain version of a mocked executable installed via `installMockedToolchain` at the given URL.
    static func getMockedToolchainVersion(at url: URL) throws -> ToolchainVersion {
        let process = Process()
        process.executableURL = url

        let outputPipe = Pipe()
        process.standardOutput = outputPipe

        try process.run()
        process.waitUntilExit()

        guard let outputData = try outputPipe.fileHandleForReading.readToEnd() else {
            throw SwiftlyTestError(message: "got no output from swift binary at path \(url.path)")
        }

        let toolchainVersion = String(decoding: outputData, as: UTF8.self).trimmingCharacters(in: .newlines)
        return try ToolchainVersion(parsing: toolchainVersion)
    }
}

public class TestOutputHandler: SwiftlyCore.OutputHandler {
    public var lines: [String]
    private let quiet: Bool

    public init(quiet: Bool) {
        self.lines = []
        self.quiet = quiet
    }

    public func handleOutputLine(_ string: String) {
        self.lines.append(string)

        if !self.quiet {
            Swift.print(string)
        }
    }
}

public class TestInputProvider: SwiftlyCore.InputProvider {
    private var lines: [String]

    public init(lines: [String]) {
        self.lines = lines
    }

    public func readLine() -> String? {
        self.lines.removeFirst()
    }
}

/// Wrapper around a `swift` executable used to execute swift commands.
public struct SwiftExecutable {
    public let path: URL

    private static let stableRegex: Regex<(Substring, Substring)> =
        try! Regex("swift-([^-]+)-RELEASE")

    private static let snapshotRegex: Regex<(Substring, Substring)> =
        try! Regex("\\(LLVM [a-z0-9]+, Swift ([a-z0-9]+)\\)")

    public func exists() -> Bool {
        self.path.fileExists()
    }

    /// Gets the version of this executable by parsing the `swift --version` output, potentially looking
    /// up the commit hash via the GitHub API.
    public func version() async throws -> ToolchainVersion {
        let process = Process()
        process.executableURL = self.path
        process.arguments = ["--version"]

        let binPath = ProcessInfo.processInfo.environment["PATH"]!
        process.environment = ["PATH": "\(self.path.deletingLastPathComponent().path):\(binPath)"]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe

        try process.run()
        process.waitUntilExit()

        guard let outputData = try outputPipe.fileHandleForReading.readToEnd() else {
            throw SwiftlyTestError(message: "got no output from swift binary at path \(self.path.path)")
        }

        let outputString = String(decoding: outputData, as: UTF8.self).trimmingCharacters(in: .newlines)

        if let match = try Self.stableRegex.firstMatch(in: outputString) {
            let versions = match.output.1.split(separator: ".")

            let major = Int(versions[0])!
            let minor = Int(versions[1])!

            let patch: Int
            if versions.count == 3 {
                patch = Int(versions[2])!
            } else {
                patch = 0
            }

            return ToolchainVersion(major: major, minor: minor, patch: patch)
        } else if let version = try? ToolchainVersion(parsing: outputString) {
            // This branch is taken if the toolchain in question is mocked.
            return version
        } else {
            throw SwiftlyTestError(message: "bad version: \(outputString)")
        }
    }
}

/// An `HTTPRequestExecutor` which will return a mocked response to any toolchain download requests.
/// All other requests are performed using an actual HTTP client.
public class MockToolchainDownloader: HTTPRequestExecutor {
    private static let releaseURLRegex: Regex<(Substring, Substring, Substring, Substring?)> =
        try! Regex("swift-(\\d+)\\.(\\d+)(?:\\.(\\d+))?-RELEASE")
    private static let snapshotURLRegex: Regex<Substring> =
        try! Regex("swift(?:-[0-9]+\\.[0-9]+)?-DEVELOPMENT-SNAPSHOT-[0-9]{4}-[0-9]{2}-[0-9]{2}")

    private let executables: [String]
#if os(Linux)
    private var signatures: [String: URL]
#endif

    private let latestSwiftlyVersion: SwiftlyVersion

    private let releaseToolchains: [ToolchainVersion.StableRelease]

    private let snapshotToolchains: [ToolchainVersion.Snapshot]

    public init(
        executables: [String]? = nil,
        latestSwiftlyVersion: SwiftlyVersion = SwiftlyCore.version,
        releaseToolchains: [ToolchainVersion.StableRelease] = [
            SwiftlyTests.oldStable.asStableRelease!,
            SwiftlyTests.newStable.asStableRelease!,
            SwiftlyTests.oldStableNewPatch.asStableRelease!,
            ToolchainVersion.StableRelease(major: 5, minor: 7, patch: 4), // Some tests look for a patch in the 5.7.x series larger than 5.0.3
            ToolchainVersion.StableRelease(major: 5, minor: 9, patch: 0), // Some tests try to update from 5.9.0
            ToolchainVersion.StableRelease(major: 5, minor: 9, patch: 1),
            ToolchainVersion.StableRelease(major: 6, minor: 0, patch: 0), // Some tests check for a release larger than 5.8.0 to be present
            ToolchainVersion.StableRelease(major: 6, minor: 0, patch: 1), // Some tests try to update from 6.0.0
            ToolchainVersion.StableRelease(major: 6, minor: 0, patch: 2), // Some tests try to update from 6.0.1
        ],
        snapshotToolchains: [ToolchainVersion.Snapshot] = [
            SwiftlyTests.oldMainSnapshot.asSnapshot!,
            SwiftlyTests.newMainSnapshot.asSnapshot!,
            SwiftlyTests.oldReleaseSnapshot.asSnapshot!,
            SwiftlyTests.newReleaseSnapshot.asSnapshot!,
        ]
    ) {
        self.executables = executables ?? ["swift"]
#if os(Linux)
        self.signatures = [:]
#endif
        self.latestSwiftlyVersion = latestSwiftlyVersion
        self.releaseToolchains = releaseToolchains
        self.snapshotToolchains = snapshotToolchains
    }

    public func getCurrentSwiftlyRelease() async throws -> Components.Schemas.SwiftlyRelease {
        let release = Components.Schemas.SwiftlyRelease(
            version: self.latestSwiftlyVersion.description,
            platforms: [
                .init(platform: .init(.darwin), arm64: "https://download.swift.org/swiftly-darwin.pkg", x8664: "https://download.swift.org/swiftly-darwin.pkg"),
                .init(platform: .init(.linux), arm64: "https://download.swift.org/swiftly-linux.tar.gz", x8664: "https://download.swift.org/swiftly-linux.tar.gz"),
            ]
        )

        return release
    }

    public func getReleaseToolchains() async throws -> [Components.Schemas.Release] {
        let currentPlatform = try await Swiftly.currentPlatform.detectPlatform(SwiftlyTests.ctx, disableConfirmation: true, platform: nil)

        let platformName = switch currentPlatform {
        case PlatformDefinition.ubuntu2004:
            "Ubuntu 20.04"
        case PlatformDefinition.amazonlinux2:
            "Amazon Linux 2"
        case PlatformDefinition.ubuntu2204:
            "Ubuntu 22.04"
        case PlatformDefinition.rhel9:
            "Red Hat Universal Base Image 9"
        case PlatformDefinition(name: "ubuntu2404", nameFull: "ubuntu24.04", namePretty: "Ubuntu 24.04"):
            "Ubuntu 24.04"
        case PlatformDefinition(name: "debian12", nameFull: "debian12", namePretty: "Debian GNU/Linux 12"):
            "Debian 12"
        case PlatformDefinition(name: "fedora39", nameFull: "fedora39", namePretty: "Fedora Linux 39"):
            "Fedora 39"
        case PlatformDefinition.macOS:
            "Xcode" // NOTE: this is not actually a platform that gets added in the swift.org API for macos/xcode
        default:
            String?.none
        }

        guard let platformName else {
            throw SwiftlyTestError(message: "Could not detect the current platform in test: \(currentPlatform)")
        }

        return self.releaseToolchains.map { releaseToolchain in
            Components.Schemas.Release(
                name: String(describing: releaseToolchain),
                date: "",
                platforms: platformName != "Xcode" ? [.init(
                    name: platformName,
                    platform: .init(value1: .linux, value2: "Linux"),
                    archs: [cpuArch]
                )] : [],
                tag: "",
                xcode: "",
                xcodeRelease: true
            )
        }
    }

    public func getSnapshotToolchains(branch: Components.Schemas.SourceBranch, platform _: Components.Schemas.PlatformIdentifier) async throws -> Components.Schemas.DevToolchains {
        let currentPlatform = try await Swiftly.currentPlatform.detectPlatform(SwiftlyTests.ctx, disableConfirmation: true, platform: nil)

        let releasesForBranch = self.snapshotToolchains.filter { snapshotVersion in
            switch snapshotVersion.branch {
            case .main:
                branch.value1 == .main || branch.value1?.rawValue == "main"
            case let .release(major, minor):
                branch.value2 == "\(major).\(minor)" || branch.value1?.rawValue == "\(major).\(minor)"
            }
        }

        let devToolchainsForArch = releasesForBranch.map { branchSnapshot in
            Components.Schemas.DevToolchainForArch(
                name: Components.Schemas.DevToolchainKind?.none,
                date: "",
                dir: branch.value1 == .main || branch.value2 == "main" ?
                    "swift-DEVELOPMENT-SNAPSHOT-\(branchSnapshot.date)" :
                    "swift-6.0-DEVELOPMENT-SNAPSHOT-\(branchSnapshot.date)",
                download: "",
                downloadSignature: nil,
                debugInfo: nil
            )
        }

        if currentPlatform == PlatformDefinition.macOS {
            return Components.Schemas.DevToolchains(universal: devToolchainsForArch)
        } else if cpuArch == Components.Schemas.Architecture.x8664 {
            return Components.Schemas.DevToolchains(x8664: devToolchainsForArch)
        } else if cpuArch == Components.Schemas.Architecture.aarch64 {
            return Components.Schemas.DevToolchains(aarch64: devToolchainsForArch)
        } else {
            return Components.Schemas.DevToolchains()
        }
    }

    public func execute(_ request: HTTPClientRequest, timeout _: TimeAmount) async throws -> HTTPClientResponse {
        guard let url = URL(string: request.url) else {
            throw SwiftlyTestError(message: "invalid request URL: \(request.url)")
        }

        if url.host == "download.swift.org" && url.path.hasPrefix("/swiftly-") {
            // Download a swiftly bundle
            return try self.makeSwiftlyDownloadResponse(from: url)
        } else if url.host == "download.swift.org" && (url.path.hasPrefix("/swift-") || url.path.hasPrefix("/development")) {
            // Download a toolchain
            return try self.makeToolchainDownloadResponse(from: url)
        } else if url.host == "www.swift.org" && url.path == "/keys/all-keys.asc" {
            return try self.makeGPGKeysResponse(from: url)
        } else {
            throw SwiftlyTestError(message: "unmocked URL: \(request)")
        }
    }

    private func makeToolchainDownloadResponse(from url: URL) throws -> HTTPClientResponse {
        let toolchain: ToolchainVersion
        if let match = try Self.releaseURLRegex.firstMatch(in: url.path) {
            var version = "\(match.output.1).\(match.output.2)."
            if let patch = match.output.3 {
                version += patch
            } else {
                version += "0"
            }
            toolchain = try ToolchainVersion(parsing: version)
        } else if let match = try Self.snapshotURLRegex.firstMatch(in: url.path) {
            let selector = try ToolchainSelector(parsing: String(match.output))
            guard case let .snapshot(branch, date) = selector else {
                throw SwiftlyTestError(message: "unexpected selector: \(selector)")
            }
            toolchain = .init(snapshotBranch: branch, date: date!)
        } else {
            throw SwiftlyTestError(message: "invalid toolchain download URL: \(url.path)")
        }

        let mockedToolchain = try self.makeMockedToolchain(toolchain: toolchain, name: url.lastPathComponent)
        return HTTPClientResponse(body: .bytes(ByteBuffer(data: mockedToolchain)))
    }

    private func makeSwiftlyDownloadResponse(from url: URL) throws -> HTTPClientResponse {
        let mockedSwiftly = try self.makeMockedSwiftly(from: url)
        return HTTPClientResponse(body: .bytes(ByteBuffer(data: mockedSwiftly)))
    }

    private func makeGPGKeysResponse(from _: URL) throws -> HTTPClientResponse {
        // Give GPG the test's private signature here as trusted
        HTTPClientResponse(body: .bytes(ByteBuffer(data: Data(PackageResources.mock_signing_key_private_pgp))))
    }

#if os(Linux)
    public func makeMockedSwiftly(from url: URL) throws -> Data {
        // Check our cache if this is a signature request
        if url.path.hasSuffix(".sig") {
            // Signatures will either be in the cache or this don't exist
            guard let signature = self.signatures["swiftly"] else {
                throw SwiftlyTestError(message: "swiftly signature wasn't found in the cache")
            }

            return try Data(contentsOf: signature)
        }

        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("swiftly-\(UUID())")
        let swiftlyDir = tmp.appendingPathComponent("swiftly", isDirectory: true)

        try FileManager.default.createDirectory(
            at: swiftlyDir,
            withIntermediateDirectories: true
        )

        for executable in ["swiftly"] {
            let executablePath = swiftlyDir.appendingPathComponent(executable)

            let script = """
            #!/usr/bin/env sh

            echo 'Installed'
            """

            let data = Data(script.utf8)
            try data.write(to: executablePath)

            // make the file executable
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executablePath.path)
        }

        let archive = tmp.appendingPathComponent("swiftly.tar.gz")

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["bash", "-c", "tar -C \(swiftlyDir.path) -czf \(archive.path) swiftly"]

        try task.run()
        task.waitUntilExit()

        // Extra step involves generating a gpg signature and putting that in a cache for a later request. We will
        // use a local key for this to avoid running into entropy problems in CI.
        let gpgKeyFile = FileManager.default.temporaryDirectory.appendingPathComponent("swiftly-\(UUID())")
        try Data(PackageResources.mock_signing_key_private_pgp).write(to: gpgKeyFile)
        let importKey = Process()
        importKey.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        importKey.arguments = ["bash", "-c", """
        export GNUPGHOME="\(SwiftlyTests.ctx.mockedHomeDir!.path)/.gnupg"
        gpg --batch --import \(gpgKeyFile.path) >/dev/null 2>&1 || echo -n
        """]
        try importKey.run()
        importKey.waitUntilExit()
        if importKey.terminationStatus != 0 {
            throw SwiftlyTestError(message: "unable to import test gpg signing key")
        }

        let detachSign = Process()
        detachSign.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        detachSign.arguments = ["bash", "-c", """
        export GPG_TTY=$(tty)
        export GNUPGHOME="\(SwiftlyTests.ctx.mockedHomeDir!.path)/.gnupg"
        gpg --version | grep '2.0.' > /dev/null
        if [ "$?" == "0" ]; then
            gpg --default-key "A2A645E5249D25845C43954E7D210032D2F670B7" --detach-sign "\(archive.path)"
        else
            gpg --pinentry-mode loopback --default-key "A2A645E5249D25845C43954E7D210032D2F670B7" --detach-sign "\(archive.path)"
        fi
        """]
        try detachSign.run()
        detachSign.waitUntilExit()

        if detachSign.terminationStatus != 0 {
            throw SwiftlyTestError(message: "unable to sign archive using the test user's gpg key")
        }

        self.signatures["swiftly"] = archive.appendingPathExtension("sig")

        return try Data(contentsOf: archive)
    }

    public func makeMockedToolchain(toolchain: ToolchainVersion, name: String) throws -> Data {
        // Check our cache if this is a signature request
        if name.hasSuffix(".sig") {
            // Signatures will either be in the cache or they don't exist
            guard let signature = self.signatures[toolchain.name] else {
                throw SwiftlyTestError(message: "signature wasn't found in the cache")
            }

            return try Data(contentsOf: signature)
        }

        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("swiftly-\(UUID())")
        let toolchainDir = tmp.appendingPathComponent("toolchain", isDirectory: true)
        let toolchainBinDir = toolchainDir
            .appendingPathComponent("usr", isDirectory: true)
            .appendingPathComponent("bin", isDirectory: true)

        try FileManager.default.createDirectory(
            at: toolchainBinDir,
            withIntermediateDirectories: true
        )

        for executable in self.executables {
            let executablePath = toolchainBinDir.appendingPathComponent(executable)

            let script = """
            #!/usr/bin/env sh

            echo '\(toolchain.name)'
            """

            let data = Data(script.utf8)
            try data.write(to: executablePath)

            // make the file executable
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executablePath.path)
        }

        let archive = tmp.appendingPathComponent("toolchain.tar.gz")

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["bash", "-c", "tar -C \(tmp.path) -czf \(archive.path) \(toolchainDir.lastPathComponent)"]

        try task.run()
        task.waitUntilExit()

        // Extra step involves generating a gpg signature and putting that in a cache for a later request. We will
        // use a local key for this to avoid running into entropy problems in CI.
        let gpgKeyFile = FileManager.default.temporaryDirectory.appendingPathComponent("swiftly-\(UUID())")
        try Data(PackageResources.mock_signing_key_private_pgp).write(to: gpgKeyFile)
        let importKey = Process()
        importKey.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        importKey.arguments = ["bash", "-c", """
        export GNUPGHOME="\(SwiftlyTests.ctx.mockedHomeDir!.path)/.gnupg"
        gpg --batch --import \(gpgKeyFile.path) >/dev/null 2>&1 || echo -n
        """]
        try importKey.run()
        importKey.waitUntilExit()
        if importKey.terminationStatus != 0 {
            throw SwiftlyTestError(message: "unable to import test gpg signing key")
        }

        let detachSign = Process()
        detachSign.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        detachSign.arguments = ["bash", "-c", """
        export GPG_TTY=$(tty)
        export GNUPGHOME="\(SwiftlyTests.ctx.mockedHomeDir!.path)/.gnupg"
        gpg --version | grep '2.0.' > /dev/null
        if [ "$?" == "0" ]; then
            gpg --default-key "A2A645E5249D25845C43954E7D210032D2F670B7" --detach-sign "\(archive.path)"
        else
            gpg --pinentry-mode loopback --default-key "A2A645E5249D25845C43954E7D210032D2F670B7" --detach-sign "\(archive.path)"
        fi
        """]
        try detachSign.run()
        detachSign.waitUntilExit()

        if detachSign.terminationStatus != 0 {
            throw SwiftlyTestError(message: "unable to sign archive using the test user's gpg key")
        }

        self.signatures[toolchain.name] = archive.appendingPathExtension("sig")

        return try Data(contentsOf: archive)
    }

#elseif os(macOS)
    public func makeMockedSwiftly(from _: URL) throws -> Data {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("swiftly-\(UUID())")
        let swiftlyDir = tmp.appendingPathComponent(".swiftly", isDirectory: true)
        let swiftlyBinDir = swiftlyDir.appendingPathComponent("bin")

        try FileManager.default.createDirectory(
            at: swiftlyBinDir,
            withIntermediateDirectories: true
        )

        defer {
            try? FileManager.default.removeItem(at: tmp)
        }

        for executable in ["swiftly"] {
            let executablePath = swiftlyBinDir.appendingPathComponent(executable)

            let script = """
            #!/usr/bin/env sh

            echo 'Installed.'
            """

            let data = Data(script.utf8)
            try data.write(to: executablePath)

            // make the file executable
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executablePath.path)
        }

        let pkg = tmp.appendingPathComponent("swiftly.pkg")

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = [
            "pkgbuild",
            "--root",
            swiftlyDir.path,
            "--install-location",
            ".swiftly",
            "--version",
            "\(self.latestSwiftlyVersion)",
            "--identifier",
            "org.swift.swiftly",
            pkg.path,
        ]
        try task.run()
        task.waitUntilExit()

        return try Data(contentsOf: pkg)
    }

    public func makeMockedToolchain(toolchain: ToolchainVersion, name _: String) throws -> Data {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("swiftly-\(UUID())")
        let toolchainDir = tmp.appendingPathComponent("toolchain", isDirectory: true)
        let toolchainBinDir = toolchainDir.appendingPathComponent("usr/bin", isDirectory: true)

        try FileManager.default.createDirectory(
            at: toolchainBinDir,
            withIntermediateDirectories: true
        )

        defer {
            try? FileManager.default.removeItem(at: tmp)
        }

        for executable in self.executables {
            let executablePath = toolchainBinDir.appendingPathComponent(executable)

            let script = """
            #!/usr/bin/env sh

            echo '\(toolchain.name)'
            """

            let data = Data(script.utf8)
            try data.write(to: executablePath)

            // make the file executable
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executablePath.path)
        }

        // Add a skeletal Info.plist at the top
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        let pkgInfo = SwiftPkgInfo(CFBundleIdentifier: "org.swift.swift.mock.\(toolchain.name)")
        let data = try encoder.encode(pkgInfo)
        try data.write(to: toolchainDir.appendingPathComponent("Info.plist"))

        let pkg = tmp.appendingPathComponent("toolchain.pkg")

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = [
            "pkgbuild",
            "--root",
            toolchainDir.path,
            "--install-location",
            "Library/Developer/Toolchains/\(toolchain.identifier).xctoolchain",
            "--version",
            "\(toolchain.name)",
            "--identifier",
            pkgInfo.CFBundleIdentifier,
            pkg.path,
        ]
        try task.run()
        task.waitUntilExit()

        return try Data(contentsOf: pkg)
    }

#endif
}
