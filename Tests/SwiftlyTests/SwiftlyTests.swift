import _StringProcessing
import ArgumentParser
import AsyncHTTPClient
import NIO
@testable import Swiftly
@testable import SwiftlyCore
import XCTest

#if os(macOS)
import MacOSPlatform
#endif

import AsyncHTTPClient
import NIO

struct SwiftlyTestError: LocalizedError {
    let message: String
}

public class SwiftlyTests: XCTestCase {
    override public class func tearDown() {
#if os(Linux)
        let deleteTestGPGKeys = Process()
        deleteTestGPGKeys.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        deleteTestGPGKeys.arguments = [
            "bash",
            "-c",
            """
            gpg --batch --yes --delete-secret-keys --fingerprint "A2A645E5249D25845C43954E7D210032D2F670B7" >/dev/null 2>&1
            gpg --batch --yes --delete-keys --fingerprint "A2A645E5249D25845C43954E7D210032D2F670B7" >/dev/null 2>&1
            """,
        ]
        try? deleteTestGPGKeys.run()
        deleteTestGPGKeys.waitUntilExit()
#endif
    }

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

    func baseTestConfig() async throws -> Config {
        guard let pd = try? await Swiftly.currentPlatform.detectPlatform(disableConfirmation: true, platform: nil) else {
            throw SwiftlyTestError(message: "Unable to detect the current platform.")
        }

        return Config(
            inUse: nil,
            installedToolchains: [],
            platform: pd
        )
    }

    func parseCommand<T: ParsableCommand>(_ commandType: T.Type, _ arguments: [String]) throws -> T {
        let rawCmd = try Swiftly.parseAsRoot(arguments)

        guard let cmd = rawCmd as? T else {
            throw SwiftlyTestError(
                message: "expected \(arguments) to parse as \(commandType) but got \(rawCmd) instead"
            )
        }

        return cmd
    }

    class func getTestHomePath(name: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("swiftly-tests-\(name)-\(UUID())")
    }

    /// Create a fresh swiftly home directory, populate it with a base config, and run the provided closure.
    /// Any swiftly commands executed in the closure will use this new home directory.
    ///
    /// The home directory will be deleted after the provided closure has been executed.
    func withTestHome(
        name: String = "testHome",
        _ f: () async throws -> Void
    ) async throws {
        let testHome = Self.getTestHomePath(name: name)
        SwiftlyCore.mockedHomeDir = testHome
        defer {
            SwiftlyCore.mockedHomeDir = nil
            try? testHome.deleteIfExists()
        }
        for dir in Swiftly.requiredDirectories {
            try dir.deleteIfExists()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: false)
        }

        let config = try await self.baseTestConfig()
        try config.save()

        let cwd = FileManager.default.currentDirectoryPath
        defer {
            FileManager.default.changeCurrentDirectoryPath(cwd)
        }

        FileManager.default.changeCurrentDirectoryPath(testHome.path)

        try await f()
    }

    func withMockedHome(
        homeName: String,
        toolchains: Set<ToolchainVersion>,
        inUse: ToolchainVersion? = nil,
        f: () async throws -> Void
    ) async throws {
        try await self.withTestHome(name: homeName) {
            for toolchain in toolchains {
                try await self.installMockedToolchain(toolchain: toolchain)
            }

            if !toolchains.isEmpty {
                var use = try self.parseCommand(Use.self, ["use", inUse?.name ?? "latest"])
                try await use.run()
            } else {
                try FileManager.default.createDirectory(
                    at: Swiftly.currentPlatform.swiftlyBinDir,
                    withIntermediateDirectories: true
                )
            }

            try await f()
        }
    }

    func withMockedSwiftlyVersion(latestSwiftlyVersion: SwiftlyVersion = SwiftlyCore.version, _ f: () async throws -> Void) async throws {
        let prevExecutor = SwiftlyCore.httpRequestExecutor
        let mockDownloader = MockToolchainDownloader(executables: ["swift"], latestSwiftlyVersion: latestSwiftlyVersion, delegate: prevExecutor)
        SwiftlyCore.httpRequestExecutor = mockDownloader
        defer {
            SwiftlyCore.httpRequestExecutor = prevExecutor
        }

        try await f()
    }

    func withMockedToolchain(executables: [String]? = nil, f: () async throws -> Void) async throws {
        let prevExecutor = SwiftlyCore.httpRequestExecutor
        let mockDownloader = MockToolchainDownloader(executables: executables, delegate: prevExecutor)
        SwiftlyCore.httpRequestExecutor = mockDownloader
        defer {
            SwiftlyCore.httpRequestExecutor = prevExecutor
        }

        try await f()
    }

    func withMockedHTTPRequests(_ handler: @escaping (HTTPClientRequest) async throws -> HTTPClientResponse, _ f: () async throws -> Void) async throws {
        let prevExecutor = SwiftlyCore.httpRequestExecutor
        let mockedRequestExecutor = MockHTTPRequestExecutor(handler: handler)
        SwiftlyCore.httpRequestExecutor = mockedRequestExecutor
        defer {
            SwiftlyCore.httpRequestExecutor = prevExecutor
        }

        try await f()
    }

    /// Backup and rollback local changes to the user's installation.
    ///
    /// Backup the user's swiftly installation before running the provided
    /// function and roll it all back afterwards.
    func rollbackLocalChanges(_ f: () async throws -> Void) async throws {
        let userHome = FileManager.default.homeDirectoryForCurrentUser

        // Backup user profile changes in case of init tests
        let profiles = [".profile", ".zprofile", ".bash_profile", ".bash_login", ".config/fish/conf.d/swiftly.fish"]
        for profile in profiles {
            let config = userHome.appendingPathComponent(profile)
            let backupConfig = config.appendingPathExtension("swiftly-test-backup")
            _ = try? FileManager.default.copyItem(at: config, to: backupConfig)
        }
        defer {
            for profile in profiles.reversed() {
                let config = userHome.appendingPathComponent(profile)
                let backupConfig = config.appendingPathExtension("swiftly-test-backup")
                if backupConfig.fileExists() {
                    if config.fileExists() {
                        try? FileManager.default.removeItem(at: config)
                    }
                    try? FileManager.default.moveItem(at: backupConfig, to: config)
                } else if config.fileExists() {
                    try? FileManager.default.removeItem(at: config)
                }
            }
        }

#if os(macOS)
        // In some environments, such as CI, we can't install directly to the user's home directory
        try await self.withTestHome(name: "e2eHome") { try await f() }
        return
#endif

        // Backup config, toolchain, and bin directory
        let swiftlyFiles = [Swiftly.currentPlatform.swiftlyHomeDir, Swiftly.currentPlatform.swiftlyToolchainsDir, Swiftly.currentPlatform.swiftlyBinDir]
        for file in swiftlyFiles {
            let backupFile = file.appendingPathExtension("swiftly-test-backup")
            _ = try? FileManager.default.moveItem(at: file, to: backupFile)

            if file == Swiftly.currentPlatform.swiftlyConfigFile {
                _ = try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            } else {
                _ = try? FileManager.default.createDirectory(at: file, withIntermediateDirectories: true)
            }
        }
        defer {
            for file in swiftlyFiles.reversed() {
                let backupFile = file.appendingPathExtension("swiftly-test-backup")
                if backupFile.fileExists() {
                    if file.fileExists() {
                        try? FileManager.default.removeItem(at: file)
                    }
                    try? FileManager.default.moveItem(at: backupFile, to: file)
                } else if file.fileExists() {
                    try? FileManager.default.removeItem(at: file)
                }
            }
        }

        // create an empty config file and toolchains directory for the test
        let c = try await self.baseTestConfig()
        try c.save()

        try await f()
    }

    /// Validates that the provided toolchain is the one currently marked as "in use", both by checking the
    /// configuration file and by executing `swift --version` using the swift executable in the `bin` directory.
    /// If nil is provided, this validates that no toolchain is currently in use.
    func validateInUse(expected: ToolchainVersion?) async throws {
        let config = try Config.load()
        XCTAssertEqual(config.inUse, expected)
    }

    /// Validate that all of the provided toolchains have been installed.
    ///
    /// This method ensures that config.json reflects the expected installed toolchains and also
    /// validates that the toolchains on disk match their expected versions via `swift --version`.
    func validateInstalledToolchains(_ toolchains: Set<ToolchainVersion>, description: String) async throws {
        let config = try Config.load()

        guard config.installedToolchains == toolchains else {
            throw SwiftlyTestError(message: "\(description): expected \(toolchains) but got \(config.installedToolchains)")
        }

#if os(Linux)
        // Verify that the toolchains on disk correspond to those in the config.
        for toolchain in toolchains {
            let toolchainDir = Swiftly.currentPlatform.swiftlyHomeDir
                .appendingPathComponent("toolchains")
                .appendingPathComponent(toolchain.name)
            XCTAssertTrue(toolchainDir.fileExists())

            let swiftBinary = toolchainDir
                .appendingPathComponent("usr")
                .appendingPathComponent("bin")
                .appendingPathComponent("swift")

            let executable = SwiftExecutable(path: swiftBinary)
            let actualVersion = try await executable.version()
            XCTAssertEqual(actualVersion, toolchain)
        }
#endif
    }

    /// Install a mocked toolchain according to the provided selector that includes the provided list of executables
    /// in its bin directory.
    ///
    /// When executed, the mocked executables will simply print the toolchain version and return.
    func installMockedToolchain(selector: String, args: [String] = [], executables: [String]? = nil) async throws {
        var install = try self.parseCommand(Install.self, ["install", "\(selector)", "--no-verify", "--post-install-file=\(Swiftly.currentPlatform.getTempFilePath().path)"] + args)

        try await self.withMockedToolchain(executables: executables) {
            try await install.run()
        }
    }

    /// Install a mocked toolchain according to the provided selector that includes the provided list of executables
    /// in its bin directory.
    ///
    /// When executed, the mocked executables will simply print the toolchain version and return.
    func installMockedToolchain(toolchain: ToolchainVersion, executables: [String]? = nil) async throws {
        try await self.installMockedToolchain(selector: "\(toolchain.name)", executables: executables)
    }

    /// Install a mocked toolchain associated with the given version that includes the provided list of executables
    /// in its bin directory.
    ///
    /// When executed, the mocked executables will simply print the toolchain version and return.
    func installMockedToolchain(selector: ToolchainSelector, executables: [String]? = nil) async throws {
        try await self.installMockedToolchain(selector: "\(selector)", executables: executables)
    }

    /// Get the toolchain version of a mocked executable installed via `installMockedToolchain` at the given URL.
    func getMockedToolchainVersion(at url: URL) throws -> ToolchainVersion {
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

    func snapshotsAvailable() async throws -> Bool {
        let pd = try await Swiftly.currentPlatform.detectPlatform(disableConfirmation: true, platform: nil)

        // Snapshots are currently unavailable for these platforms on swift.org
        // TODO: remove these once snapshots are available for them
        let snapshotsUnavailable: [PlatformDefinition] = [
            .ubuntu2404,
            .fedora39,
            .debian12,
        ]

        return !snapshotsUnavailable.contains(pd)
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

extension SwiftlyCommand {
    /// Run this command, using the provided input as the stdin (in lines). Returns an array of captured
    /// output lines.
    mutating func runWithMockedIO(quiet: Bool = false, input: [String]? = nil) async throws -> [String] {
        let handler = TestOutputHandler(quiet: quiet)
        SwiftlyCore.outputHandler = handler
        defer {
            SwiftlyCore.outputHandler = nil
        }

        if let input {
            SwiftlyCore.inputProvider = TestInputProvider(lines: input)
        }
        defer {
            SwiftlyCore.inputProvider = nil
        }

        try await self.run()
        return handler.lines
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

/// An `HTTPRequestExecutor` that responds to all HTTP requests by invoking the provided closure.
private struct MockHTTPRequestExecutor: HTTPRequestExecutor {
    private let handler: (HTTPClientRequest) async throws -> HTTPClientResponse

    public init(handler: @escaping (HTTPClientRequest) async throws -> HTTPClientResponse) {
        self.handler = handler
    }

    public func execute(_ request: HTTPClientRequest, timeout _: TimeAmount) async throws -> HTTPClientResponse {
        try await self.handler(request)
    }

    public func getCurrentSwiftlyRelease() async throws -> Components.Schemas.SwiftlyRelease {
        throw SwiftlyTestError(message: "Mocking of fetching the current swiftly release is not implemented in MockHTTPRequestExecutor.")
    }

    public func getReleaseToolchains() async throws -> [Components.Schemas.Release] {
        throw SwiftlyTestError(message: "Mocking of fetching the release toolchains is not implemented in MockHTTPRequestExecutor.")
    }

    public func getSnapshotToolchains(branch _: Components.Schemas.SourceBranch, platform _: Components.Schemas.PlatformIdentifier) async throws -> Components.Schemas.DevToolchains {
        throw SwiftlyTestError(message: "Mocking of fetching the snapshot toolchains is not implemented in MockHTTPRequestExecutor.")
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
    private let delegate: HTTPRequestExecutor

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
        ],
        delegate: HTTPRequestExecutor
    ) {
        self.executables = executables ?? ["swift"]
#if os(Linux)
        self.signatures = [:]
#endif
        self.delegate = delegate
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
        let currentPlatform = try await Swiftly.currentPlatform.detectPlatform(disableConfirmation: true, platform: nil)

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
        let currentPlatform = try await Swiftly.currentPlatform.detectPlatform(disableConfirmation: true, platform: nil)

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

    public func execute(_ request: HTTPClientRequest, timeout: TimeAmount) async throws -> HTTPClientResponse {
        guard let url = URL(string: request.url) else {
            throw SwiftlyTestError(message: "invalid request URL: \(request.url)")
        }

        if url.host == "download.swift.org" && url.path.hasPrefix("/swiftly-") {
            // Download a swiftly bundle
            return try self.makeSwiftlyDownloadResponse(from: url)
        } else if url.host == "download.swift.org" && (url.path.hasPrefix("/swift-") || url.path.hasPrefix("/development")) {
            // Download a toolchain
            return try self.makeToolchainDownloadResponse(from: url)
        } else if url.host == "www.swift.org" {
            // Delegate any API requests to swift.org
            return try await self.delegate.execute(request, timeout: timeout)
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
        mkdir -p $HOME/.gnupg
        touch $HOME/.gnupg/gpg.conf
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
        mkdir -p $HOME/.gnupg
        touch $HOME/.gnupg/gpg.conf
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
        let swiftlyDir = tmp.appendingPathComponent("swiftly", isDirectory: true)
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
            "usr/local",
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
