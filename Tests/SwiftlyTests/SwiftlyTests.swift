import _StringProcessing
import ArgumentParser
import Foundation
import OpenAPIRuntime
@testable import Swiftly
@testable import SwiftlyCore
import SwiftlyWebsiteAPI
import Testing

#if os(macOS)
import MacOSPlatform
#endif

import AsyncHTTPClient
import NIO

import SystemPackage

struct SwiftlyTestError: LocalizedError {
    let message: String
}

extension Tag {
    @Tag static var medium: Self
    @Tag static var large: Self
}

extension Executable {
    public func exists() async throws -> Bool {
        switch self.storage {
        case let .path(p):
            return (try await FileSystem.exists(atPath: p))
        case let .executable(e):
            let path = ProcessInfo.processInfo.environment["PATH"]

            guard let path else { return false }

            for p in path.split(separator: ":") {
                if try await FileSystem.exists(atPath: FilePath(String(p)) / e) {
                    return true
                }
            }

            return false
        }
    }
}

let unmockedMsg = "All swiftly test case logic must be mocked in order to prevent mutation of the system running the test. This test must either run swiftly components inside a SwiftlyTests.with... closure, or it must have one of the @Test traits, such as @Test(.testHome), or @Test(.mock...)"

actor OutputHandlerFail: OutputHandler {
    func handleOutputLine(_: String) {
        fatalError(unmockedMsg)
    }
}

actor InputProviderFail: InputProvider {
    func readLine() -> String? {
        fatalError(unmockedMsg)
    }
}

struct HTTPRequestExecutorFail: HTTPRequestExecutor {
    func getCurrentSwiftlyRelease() async throws -> SwiftlyWebsiteAPI.Components.Schemas.SwiftlyRelease { fatalError(unmockedMsg) }
    func getReleaseToolchains() async throws -> [Components.Schemas.Release] { fatalError(unmockedMsg) }
    func getSnapshotToolchains(branch _: SwiftlyWebsiteAPI.Components.Schemas.SourceBranch, platform _: SwiftlyWebsiteAPI.Components.Schemas.PlatformIdentifier) async throws -> SwiftlyWebsiteAPI.Components.Schemas.DevToolchains { fatalError(unmockedMsg) }
    func getGpgKeys() async throws -> OpenAPIRuntime.HTTPBody { fatalError(unmockedMsg) }
    func getSwiftlyRelease(url _: URL) async throws -> OpenAPIRuntime.HTTPBody { fatalError(unmockedMsg) }
    func getSwiftlyReleaseSignature(url _: URL) async throws -> OpenAPIRuntime.HTTPBody { fatalError(unmockedMsg) }
    func getSwiftToolchainFile(_: ToolchainFile) async throws -> OpenAPIRuntime.HTTPBody { fatalError(unmockedMsg) }
    func getSwiftToolchainFileSignature(_: ToolchainFile) async throws
        -> OpenAPIRuntime.HTTPBody { fatalError(unmockedMsg) }
}

// Convenience extensions to common Swiftly and SwiftlyCore types to set the correct context

extension Config {
    public static func load() async throws -> Config {
        try await Config.load(SwiftlyTests.ctx)
    }

    public func save() throws {
        try self.save(SwiftlyTests.ctx)
    }
}

extension SwiftlyCoreContext {
    public init(
        mockedHomeDir: FilePath?,
        httpRequestExecutor: HTTPRequestExecutor,
        outputHandler: (any OutputHandler)?,
        inputProvider: (any InputProvider)?
    ) {
        self.init(httpClient: SwiftlyHTTPClient(httpRequestExecutor: httpRequestExecutor))

        self.mockedHomeDir = mockedHomeDir
        self.currentDirectory = mockedHomeDir ?? fs.cwd
        self.httpClient = SwiftlyHTTPClient(httpRequestExecutor: httpRequestExecutor)
        self.outputHandler = outputHandler
        self.inputProvider = inputProvider
    }
}

extension ToolchainVersion {
    public static let oldStable = ToolchainVersion(major: 5, minor: 6, patch: 0)
    public static let oldStableNewPatch = ToolchainVersion(major: 5, minor: 6, patch: 3)
    public static let newStable = ToolchainVersion(major: 5, minor: 7, patch: 0)
    public static let oldMainSnapshot = ToolchainVersion(snapshotBranch: .main, date: "2025-03-10")
    public static let newMainSnapshot = ToolchainVersion(snapshotBranch: .main, date: "2025-03-14")
    public static let oldReleaseSnapshot = ToolchainVersion(snapshotBranch: .release(major: 6, minor: 0), date: "2025-02-09")
    public static let newReleaseSnapshot = ToolchainVersion(snapshotBranch: .release(major: 6, minor: 0), date: "2025-02-11")
}

extension Set where Element == ToolchainVersion {
    static func allToolchains() -> Set<ToolchainVersion> { [
        .oldStable,
        .oldStableNewPatch,
        .newStable,
        .oldMainSnapshot,
        .newMainSnapshot,
        .oldReleaseSnapshot,
        .newReleaseSnapshot,
    ] }
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

// extension Trait for mockedSwiftlyVersion
struct MockedSwiftlyVersionTrait: TestTrait, TestScoping {
    var name: String = "testHome"

    init(_ name: String) { self.name = name }

    func provideScope(for _: Test, testCase _: Test.Case?, performing function: @Sendable () async throws -> Void) async throws {
        try await SwiftlyTests.withMockedSwiftlyVersion(latestSwiftlyVersion: SwiftlyVersion(major: SwiftlyCore.version.major, minor: 0, patch: 0)) {
            try await function()
        }
    }
}

extension Trait where Self == MockedSwiftlyVersionTrait {
    static func mockedSwiftlyVersion(_ name: String = "testHome") -> Self { Self(name) }
}

struct MockHomeToolchainsTrait: TestTrait, TestScoping {
    var name: String = "testHome"
    var toolchains: Set<ToolchainVersion> = .allToolchains()
    var inUse: ToolchainVersion?

    init(_ name: String, toolchains: Set<ToolchainVersion>, inUse: ToolchainVersion?) {
        self.name = name
        self.toolchains = toolchains
        self.inUse = inUse
    }

    func provideScope(for _: Test, testCase _: Test.Case?, performing function: @Sendable () async throws -> Void) async throws {
        try await SwiftlyTests.withMockedHome(homeName: self.name, toolchains: self.toolchains, inUse: self.inUse) {
            try await function()
        }
    }
}

extension Trait where Self == MockHomeToolchainsTrait {
    /// Run the test with this trait to get a mocked home directory with a predefined collection of toolchains already installed.
    static func mockHomeToolchains(_ homeName: String = "testHome", toolchains: Set<ToolchainVersion> = .allToolchains(), inUse: ToolchainVersion? = nil) -> Self { Self(homeName, toolchains: toolchains, inUse: inUse) }
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
    /// toolchain.
    static func testHomeMockedToolchain(_ name: String = "testHome") -> Self { Self(name) }
}

public enum SwiftlyTests {
    @TaskLocal static var ctx: SwiftlyCoreContext = .init(
        mockedHomeDir: .init("/does/not/exist"),
        httpRequestExecutor: HTTPRequestExecutorFail(),
        outputHandler: OutputHandlerFail(),
        inputProvider: InputProviderFail()
    )

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

        return await handler.lines
    }

    static func getTestHomePath(name: String) -> FilePath {
        fs.tmp / "swiftly-tests-\(name)-\(UUID())"
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

        let ctx = SwiftlyCoreContext(
            mockedHomeDir: testHome,
            httpRequestExecutor: SwiftlyTests.ctx.httpClient.httpRequestExecutor,
            outputHandler: nil,
            inputProvider: nil
        )

        try await fs.withTemporary(files: [testHome] + Swiftly.requiredDirectories(ctx)) {
            for dir in Swiftly.requiredDirectories(ctx) {
                try FileManager.default.deleteIfExists(atPath: dir)
                try await fs.mkdir(atPath: dir)
            }

            let config = try await Self.baseTestConfig()
            try config.save(ctx)

            try await Self.$ctx.withValue(ctx) {
                try await f()
            }
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

            var cleanBinDir = false

            if !toolchains.isEmpty {
                try await Self.runCommand(Use.self, ["use", inUse?.name ?? "latest"])
            } else {
                try await fs.mkdir(.parents, atPath: Swiftly.currentPlatform.swiftlyBinDir(Self.ctx))
                cleanBinDir = true
            }

            do {
                try await f()

                if cleanBinDir {
                    try await fs.remove(atPath: Swiftly.currentPlatform.swiftlyBinDir(Self.ctx))
                }
            } catch {
                if cleanBinDir {
                    try await fs.remove(atPath: Swiftly.currentPlatform.swiftlyBinDir(Self.ctx))
                }
            }
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
        let config = try await Config.load()
        #expect(config.inUse == expected)
    }

    /// Validate that all of the provided toolchains have been installed.
    ///
    /// This method ensures that config.json reflects the expected installed toolchains and also
    /// validates that the toolchains on disk match their expected versions via `swift --version`.
    static func validateInstalledToolchains(_ toolchains: Set<ToolchainVersion>, description: String) async throws {
        let config = try await Config.load()

        guard config.installedToolchains == toolchains else {
            throw SwiftlyTestError(message: "\(description): expected \(toolchains) but got \(config.installedToolchains)")
        }

#if os(macOS)
        for toolchain in toolchains {
            let toolchainDir = Self.ctx.mockedHomeDir! / "Toolchains/\(toolchain.identifier).xctoolchain"
            #expect(try await fs.exists(atPath: toolchainDir))

            let swiftBinary = toolchainDir / "usr/bin/swift"

            let executable = SwiftExecutable(path: swiftBinary)
            let actualVersion = try await executable.version()
            #expect(actualVersion == toolchain)
        }
#elseif os(Linux)
        // Verify that the toolchains on disk correspond to those in the config.
        for toolchain in toolchains {
            let toolchainDir = Swiftly.currentPlatform.swiftlyHomeDir(Self.ctx) / "toolchains/\(toolchain.name)"
            #expect(try await fs.exists(atPath: toolchainDir))

            let swiftBinary = toolchainDir / "usr/bin/swift"

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
            try await Self.runCommand(Install.self, ["install", "\(selector)", "--no-verify", "--post-install-file=\(fs.mktemp())"] + args)
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

    /// Get the toolchain version of a mocked executable installed via `installMockedToolchain` at the given FilePath.
    static func getMockedToolchainVersion(at path: FilePath) throws -> ToolchainVersion {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path.string)

        let outputPipe = Pipe()
        process.standardOutput = outputPipe

        try process.run()
        process.waitUntilExit()

        guard let outputData = try outputPipe.fileHandleForReading.readToEnd() else {
            throw SwiftlyTestError(message: "got no output from swift binary at path \(path)")
        }

        let toolchainVersion = String(decoding: outputData, as: UTF8.self).trimmingCharacters(in: .newlines)
        return try ToolchainVersion(parsing: toolchainVersion)
    }
}

public actor TestOutputHandler: SwiftlyCore.OutputHandler {
    private(set) var lines: [String]
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

public actor TestInputProvider: SwiftlyCore.InputProvider {
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
    public let path: FilePath

    private static func stableRegex() -> Regex<(Substring, Substring)> {
        try! Regex("swift-([^-]+)-RELEASE")
    }

    public func exists() async throws -> Bool {
        try await fs.exists(atPath: self.path)
    }

    /// Gets the version of this executable by parsing the `swift --version` output, potentially looking
    /// up the commit hash via the GitHub API.
    public func version() async throws -> ToolchainVersion {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: self.path.string)
        process.arguments = ["--version"]

        let binPath = ProcessInfo.processInfo.environment["PATH"]!
        process.environment = ["PATH": "\(self.path.removingLastComponent()):\(binPath)"]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe

        try process.run()
        process.waitUntilExit()

        guard let outputData = try outputPipe.fileHandleForReading.readToEnd() else {
            throw SwiftlyTestError(message: "got no output from swift binary at path \(self.path)")
        }

        let outputString = String(decoding: outputData, as: UTF8.self).trimmingCharacters(in: .newlines)

        if let match = try Self.stableRegex().firstMatch(in: outputString) {
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
public final actor MockToolchainDownloader: HTTPRequestExecutor {
    private static func releaseURLRegex() -> Regex<(Substring, Substring, Substring, Substring?)> {
        try! Regex("swift-(\\d+)\\.(\\d+)(?:\\.(\\d+))?-RELEASE")
    }

    private static func snapshotURLRegex() -> Regex<Substring> {
        try! Regex("swift(?:-[0-9]+\\.[0-9]+)?-DEVELOPMENT-SNAPSHOT-[0-9]{4}-[0-9]{2}-[0-9]{2}")
    }

    private let executables: [String]
#if os(Linux)
    private var signatures: [String: Data]
#endif

    private let latestSwiftlyVersion: SwiftlyVersion

    private let releaseToolchains: [ToolchainVersion.StableRelease]

    private let snapshotToolchains: [ToolchainVersion.Snapshot]

    public init(
        executables: [String]? = nil,
        latestSwiftlyVersion: SwiftlyVersion = SwiftlyCore.version,
        releaseToolchains: [ToolchainVersion.StableRelease] = [
            ToolchainVersion.oldStable.asStableRelease!,
            ToolchainVersion.newStable.asStableRelease!,
            ToolchainVersion.oldStableNewPatch.asStableRelease!,
            ToolchainVersion.StableRelease(major: 5, minor: 7, patch: 4), // Some tests look for a patch in the 5.7.x series larger than 5.0.3
            ToolchainVersion.StableRelease(major: 5, minor: 9, patch: 0), // Some tests try to update from 5.9.0
            ToolchainVersion.StableRelease(major: 5, minor: 9, patch: 1),
            ToolchainVersion.StableRelease(major: 6, minor: 0, patch: 0), // Some tests check for a release larger than 5.8.0 to be present
            ToolchainVersion.StableRelease(major: 6, minor: 0, patch: 1), // Some tests try to update from 6.0.0
            ToolchainVersion.StableRelease(major: 6, minor: 0, patch: 2), // Some tests try to update from 6.0.1
        ],
        snapshotToolchains: [ToolchainVersion.Snapshot] = [
            ToolchainVersion.oldMainSnapshot.asSnapshot!,
            ToolchainVersion.newMainSnapshot.asSnapshot!,
            ToolchainVersion.oldReleaseSnapshot.asSnapshot!,
            ToolchainVersion.newReleaseSnapshot.asSnapshot!,
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

    public func getCurrentSwiftlyRelease() async throws -> SwiftlyWebsiteAPI.Components.Schemas.SwiftlyRelease {
        let release = SwiftlyWebsiteAPI.Components.Schemas.SwiftlyRelease(
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
            SwiftlyWebsiteAPI.Components.Schemas.Release(
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

    public func getSnapshotToolchains(branch: SwiftlyWebsiteAPI.Components.Schemas.SourceBranch, platform _: SwiftlyWebsiteAPI.Components.Schemas.PlatformIdentifier) async throws -> SwiftlyWebsiteAPI.Components.Schemas.DevToolchains {
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
            SwiftlyWebsiteAPI.Components.Schemas.DevToolchainForArch(
                name: SwiftlyWebsiteAPI.Components.Schemas.DevToolchainKind?.none,
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
            return SwiftlyWebsiteAPI.Components.Schemas.DevToolchains(universal: devToolchainsForArch)
        } else if cpuArch == SwiftlyWebsiteAPI.Components.Schemas.Architecture.x8664 {
            return SwiftlyWebsiteAPI.Components.Schemas.DevToolchains(x8664: devToolchainsForArch)
        } else if cpuArch == SwiftlyWebsiteAPI.Components.Schemas.Architecture.aarch64 {
            return SwiftlyWebsiteAPI.Components.Schemas.DevToolchains(aarch64: devToolchainsForArch)
        } else {
            return SwiftlyWebsiteAPI.Components.Schemas.DevToolchains()
        }
    }

    private func makeToolchainDownloadURL(_ toolchainFile: ToolchainFile, isSignature: Bool = false) throws -> URL {
        URL(string: "https://download.swift.org/\(toolchainFile.category)/\(toolchainFile.platform)/\(toolchainFile.version)/\(toolchainFile.file)\(isSignature ? ".sig" : "")")!
    }

    private func makeToolchainDownloadResponse(from url: URL) async throws -> OpenAPIRuntime.HTTPBody {
        let toolchain: ToolchainVersion
        if let match = try Self.releaseURLRegex().firstMatch(in: url.path) {
            var version = "\(match.output.1).\(match.output.2)."
            if let patch = match.output.3 {
                version += patch
            } else {
                version += "0"
            }
            toolchain = try ToolchainVersion(parsing: version)
        } else if let match = try Self.snapshotURLRegex().firstMatch(in: url.path) {
            let selector = try ToolchainSelector(parsing: String(match.output))
            guard case let .snapshot(branch, date) = selector else {
                throw SwiftlyTestError(message: "unexpected selector: \(selector)")
            }
            toolchain = .init(snapshotBranch: branch, date: date!)
        } else {
            throw SwiftlyTestError(message: "invalid toolchain download URL: \(url.path)")
        }

        let mockedToolchain = try await self.makeMockedToolchain(toolchain: toolchain, name: url.lastPathComponent)
        return HTTPBody(mockedToolchain)
    }

    public func getSwiftToolchainFile(_ toolchainFile: ToolchainFile) async throws -> OpenAPIRuntime.HTTPBody {
        try await self.makeToolchainDownloadResponse(from: self.makeToolchainDownloadURL(toolchainFile))
    }

    public func getSwiftToolchainFileSignature(_ toolchainFile: ToolchainFile) async throws
        -> OpenAPIRuntime.HTTPBody
    {
        try await self.makeToolchainDownloadResponse(from: self.makeToolchainDownloadURL(toolchainFile, isSignature: true))
    }

    public func getSwiftlyRelease(url: URL) async throws -> OpenAPIRuntime.HTTPBody {
        let mockedSwiftly = try await self.makeMockedSwiftly(from: url)

        return HTTPBody(Array(mockedSwiftly))
    }

    public func getSwiftlyReleaseSignature(url: URL) async throws -> OpenAPIRuntime.HTTPBody {
        let mockedSwiftly = try await self.makeMockedSwiftly(from: url)

        // FIXME: the release signature shouldn't be a mocked swiftly itself
        return HTTPBody(Array(mockedSwiftly))
    }

    public func getGpgKeys() async throws -> OpenAPIRuntime.HTTPBody {
        // Give GPG the test's private signature here as trusted
        HTTPBody(Array(Data(PackageResources.mock_signing_key_private_pgp)))
    }

#if os(Linux)
    public func makeMockedSwiftly(from url: URL) async throws -> Data {
        // Check our cache if this is a signature request
        if url.path.hasSuffix(".sig") {
            // Signatures will either be in the cache or this don't exist
            guard let signature = self.signatures["swiftly"] else {
                throw SwiftlyTestError(message: "swiftly signature wasn't found in the cache")
            }

            return signature
        }

        let tmp = fs.mktemp()
        let gpgKeyFile = fs.mktemp(ext: ".asc")

        let swiftlyDir = tmp / "swiftly"

        try await fs.mkdir(.parents, atPath: swiftlyDir)

        for executable in ["swiftly"] {
            let executablePath = swiftlyDir / executable

            let script = """
            #!/usr/bin/env sh

            echo 'Installed'
            """

            let data = Data(script.utf8)
            try data.write(to: executablePath)

            // make the file executable
            try await fs.chmod(atPath: executablePath, mode: 0o755)
        }

        let archive = tmp / "swiftly.tar.gz"

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["bash", "-c", "tar -C \(swiftlyDir) -czf \(archive) swiftly"]

        try task.run()
        task.waitUntilExit()

        // Extra step involves generating a gpg signature and putting that in a cache for a later request. We will
        // use a local key for this to avoid running into entropy problems in CI.
        try Data(PackageResources.mock_signing_key_private_pgp).write(to: gpgKeyFile)

        let importKey = Process()
        importKey.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        importKey.arguments = ["bash", "-c", """
        export GNUPGHOME="\(SwiftlyTests.ctx.mockedHomeDir!)/.gnupg"
        gpg --batch --import \(gpgKeyFile) >/dev/null 2>&1 || echo -n
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
        export GNUPGHOME="\(SwiftlyTests.ctx.mockedHomeDir!)/.gnupg"
        gpg --version | grep '2.0.' > /dev/null
        if [ "$?" == "0" ]; then
            gpg --default-key "A2A645E5249D25845C43954E7D210032D2F670B7" --detach-sign "\(archive)"
        else
            gpg --pinentry-mode loopback --default-key "A2A645E5249D25845C43954E7D210032D2F670B7" --detach-sign "\(archive)"
        fi
        """]
        try detachSign.run()
        detachSign.waitUntilExit()

        if detachSign.terminationStatus != 0 {
            throw SwiftlyTestError(message: "unable to sign archive using the test user's gpg key")
        }

        var signature = archive
        signature.extension = "gz.sig"

        self.signatures["swiftly"] = try Data(contentsOf: signature)

        let data = try Data(contentsOf: archive)

        try await fs.remove(atPath: tmp)
        try await fs.remove(atPath: gpgKeyFile)

        return data
    }

    public func makeMockedToolchain(toolchain: ToolchainVersion, name: String) async throws -> Data {
        // Check our cache if this is a signature request
        if name.hasSuffix(".sig") {
            // Signatures will either be in the cache or they don't exist
            guard let signature = self.signatures[toolchain.name] else {
                throw SwiftlyTestError(message: "signature wasn't found in the cache")
            }

            return signature
        }

        let tmp = fs.mktemp()
        let gpgKeyFile = fs.mktemp(ext: ".asc")

        let toolchainDir = tmp / "toolchain"
        let toolchainBinDir = toolchainDir / "usr/bin"

        try await fs.mkdir(.parents, atPath: toolchainBinDir)

        for executable in self.executables {
            let executablePath = toolchainBinDir / executable

            let script = """
            #!/usr/bin/env sh

            echo '\(toolchain.name)'
            """

            let data = Data(script.utf8)
            try data.write(to: executablePath)

            // make the file executable
            try await fs.chmod(atPath: executablePath, mode: 0o755)
        }

        let archive = tmp / "toolchain.tar.gz"

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["bash", "-c", "tar -C \(tmp) -czf \(archive) \(toolchainDir.lastComponent!.string)"]

        try task.run()
        task.waitUntilExit()

        // Extra step involves generating a gpg signature and putting that in a cache for a later request. We will
        // use a local key for this to avoid running into entropy problems in CI.
        try Data(PackageResources.mock_signing_key_private_pgp).write(to: gpgKeyFile)

        let importKey = Process()
        importKey.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        importKey.arguments = ["bash", "-c", """
        export GNUPGHOME="\(SwiftlyTests.ctx.mockedHomeDir!)/.gnupg"
        gpg --batch --import \(gpgKeyFile) >/dev/null 2>&1 || echo -n
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
        export GNUPGHOME="\(SwiftlyTests.ctx.mockedHomeDir!)/.gnupg"
        gpg --version | grep '2.0.' > /dev/null
        if [ "$?" == "0" ]; then
            gpg --default-key "A2A645E5249D25845C43954E7D210032D2F670B7" --detach-sign "\(archive)"
        else
            gpg --pinentry-mode loopback --default-key "A2A645E5249D25845C43954E7D210032D2F670B7" --detach-sign "\(archive)"
        fi
        """]
        try detachSign.run()
        detachSign.waitUntilExit()

        if detachSign.terminationStatus != 0 {
            throw SwiftlyTestError(message: "unable to sign archive using the test user's gpg key")
        }

        var signature = archive
        signature.extension = "gz.sig"

        self.signatures[toolchain.name] = try Data(contentsOf: signature)

        let data = try Data(contentsOf: archive)

        try await fs.remove(atPath: tmp)
        try await fs.remove(atPath: gpgKeyFile)

        return data
    }

#elseif os(macOS)
    public func makeMockedSwiftly(from _: URL) async throws -> Data {
        let tmp = fs.mktemp()

        let swiftlyDir = tmp / ".swiftly"
        let swiftlyBinDir = swiftlyDir / "bin"

        try await fs.mkdir(.parents, atPath: swiftlyBinDir)

        for executable in ["swiftly"] {
            let executablePath = swiftlyBinDir / executable

            let script = """
            #!/usr/bin/env sh

            echo 'Installed.'
            """

            let data = Data(script.utf8)
            try data.write(to: executablePath)

            // make the file executable
            try await fs.chmod(atPath: executablePath, mode: 0o755)
        }

        let pkg = tmp / "swiftly.pkg"

        try await sys.pkgbuild(
            .install_location("swiftly"),
            .version("\(self.latestSwiftlyVersion)"),
            .identifier("org.swift.swiftly"),
            .root(swiftlyDir),
            package_output_path: pkg
        )
        .run(Swiftly.currentPlatform)

        let data = try Data(contentsOf: pkg)
        try await fs.remove(atPath: tmp)
        return data
    }

    public func makeMockedToolchain(toolchain: ToolchainVersion, name _: String) async throws -> Data {
        let tmp = fs.mktemp()

        let toolchainDir = tmp.appending("toolchain")
        let toolchainBinDir = toolchainDir.appending("usr/bin")

        try await fs.mkdir(.parents, atPath: toolchainBinDir)

        for executable in self.executables {
            let executablePath = toolchainBinDir.appending(executable)

            let script = """
            #!/usr/bin/env sh

            echo '\(toolchain.name)'
            """

            let data = Data(script.utf8)
            try data.write(to: executablePath)

            // make the file executable
            try await fs.chmod(atPath: executablePath, mode: 0o755)
        }

        // Add a skeletal Info.plist at the top
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        let pkgInfo = SwiftPkgInfo(CFBundleIdentifier: "org.swift.swift.mock.\(toolchain.name)")
        let data = try encoder.encode(pkgInfo)
        try data.write(to: toolchainDir.appending("Info.plist"))

        let pkg = tmp / "toolchain.pkg"

        try await sys.pkgbuild(
            .install_location(FilePath("Library/Developer/Toolchains/\(toolchain.identifier).xctoolchain")),
            .version("\(toolchain.name)"),
            .identifier(pkgInfo.CFBundleIdentifier),
            .root(toolchainDir),
            package_output_path: pkg
        )
        .run(Swiftly.currentPlatform)

        let pkgData = try Data(contentsOf: pkg)
        try await fs.remove(atPath: tmp)

        return pkgData
    }

#endif
}
