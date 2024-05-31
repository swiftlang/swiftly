import _StringProcessing
import ArgumentParser
import AsyncHTTPClient
import NIO
@testable import Swiftly
@testable import SwiftlyCore
import XCTest

struct SwiftlyTestError: LocalizedError {
    let message: String
}

class SwiftlyTests: XCTestCase {
    // Below are some constants that can be used to write test cases.
    static let oldStable = ToolchainVersion(major: 5, minor: 6, patch: 0)
    static let oldStableNewPatch = ToolchainVersion(major: 5, minor: 6, patch: 3)
    static let newStable = ToolchainVersion(major: 5, minor: 7, patch: 0)
    static let oldMainSnapshot = ToolchainVersion(snapshotBranch: .main, date: "2022-09-10")
    static let newMainSnapshot = ToolchainVersion(snapshotBranch: .main, date: "2022-10-22")
    static let oldReleaseSnapshot = ToolchainVersion(snapshotBranch: .release(major: 5, minor: 7), date: "2022-08-27")
    static let newReleaseSnapshot = ToolchainVersion(snapshotBranch: .release(major: 5, minor: 7), date: "2022-08-30")

    static let allToolchains: Set<ToolchainVersion> = [
        oldStable,
        oldStableNewPatch,
        newStable,
        oldMainSnapshot,
        newMainSnapshot,
        oldReleaseSnapshot,
        newReleaseSnapshot,
    ]

    func baseTestConfig() throws -> Config {
        let getEnv = { varName in
            guard let v = ProcessInfo.processInfo.environment[varName] else {
                throw SwiftlyTestError(message: "environment variable \(varName) must be set in order to run tests")
            }
            return v
        }

        return Config(
            inUse: nil,
            installedToolchains: [],
            platform: PlatformDefinition(
                name: try getEnv("SWIFTLY_PLATFORM_NAME"),
                nameFull: try getEnv("SWIFTLY_PLATFORM_NAME_FULL"),
                namePretty: try getEnv("SWIFTLY_PLATFORM_NAME_PRETTY")
            )
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
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(name, isDirectory: true)
    }

    /// Create a fresh swiftly home directory, populate it with a base config, and run the provided closure.
    /// Any swiftly commands executed in the closure will use this new home directory.
    ///
    /// This method requires the SWIFTLY_PLATFORM_NAME, SWIFTLY_PLATFORM_NAME_FULL, and SWIFTLY_PLATFORM_NAME_PRETTY
    /// environment variables to be set.
    ///
    /// The home directory will be deleted after the provided closure has been executed.
    func withTestHome(
        name: String = "testHome",
        _ f: () async throws -> Void
    ) async throws {
        let testHome = Self.getTestHomePath(name: name)
        SwiftlyCore.mockedHomeDir = testHome
        try await Init.execute(assumeYes: true, noModifyProfile: true, overwrite: true, platform: nil)
        defer {
            SwiftlyCore.mockedHomeDir = nil
            try? testHome.deleteIfExists()
        }

        let config = try self.baseTestConfig()
        try config.save()

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
                var use = try self.parseCommand(Use.self, ["use", "-g", inUse?.name ?? "latest"])
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
    }

    /// Install a mocked toolchain according to the provided selector that includes the provided list of executables
    /// in its bin directory.
    ///
    /// When executed, the mocked executables will simply print the toolchain version and return.
    func installMockedToolchain(selector: String, args: [String] = [], executables: [String]? = nil) async throws {
        var install = try self.parseCommand(Install.self, ["install", "\(selector)", "--no-verify"] + args)
        install.httpClient = SwiftlyHTTPClient(executor: MockToolchainDownloader(executables: executables))
        try await install.run()
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
}

extension SwiftlyHTTPClient {
    public static func mocked(_ handler: @escaping (HTTPClientRequest) async throws -> HTTPClientResponse) -> Self {
        Self(executor: MockHTTPRequestExecutor(handler: handler))
    }
}

/// An `HTTPRequestExecutor` which will return a mocked response to any toolchain download requests.
/// All other requests are performed using an actual HTTP client.
public struct MockToolchainDownloader: HTTPRequestExecutor {
    private static let releaseURLRegex: Regex<(Substring, Substring, Substring, Substring?)> =
        try! Regex("swift-(\\d+)\\.(\\d+)(?:\\.(\\d+))?-RELEASE")
    private static let snapshotURLRegex: Regex<Substring> =
        try! Regex("swift(?:-[0-9]+\\.[0-9]+)?-DEVELOPMENT-SNAPSHOT-[0-9]{4}-[0-9]{2}-[0-9]{2}")

    private let executables: [String]
    private let httpRequestExecutor: HTTPRequestExecutor

    public init(executables: [String]? = nil) {
        self.executables = executables ?? ["swift"]
        self.httpRequestExecutor = HTTPRequestExecutorImpl()
    }

    public func execute(_ request: HTTPClientRequest, timeout: TimeAmount) async throws -> HTTPClientResponse {
        guard let url = URL(string: request.url) else {
            throw SwiftlyTestError(message: "invalid request URL: \(request.url)")
        }

        if url.host == "download.swift.org" {
            return try self.makeToolchainDownloadResponse(from: url)
        } else {
            return try await self.httpRequestExecutor.execute(request, timeout: timeout)
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

        let mockedToolchain = try self.makeMockedToolchain(toolchain: toolchain)
        return HTTPClientResponse(body: .bytes(ByteBuffer(data: mockedToolchain)))
    }

    func makeMockedToolchain(toolchain: ToolchainVersion) throws -> Data {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("swiftly-\(UUID())")
        let toolchainDir = tmp.appendingPathComponent("toolchain", isDirectory: true)
        let toolchainBinDir = toolchainDir
            .appendingPathComponent("usr", isDirectory: true)
            .appendingPathComponent("bin", isDirectory: true)

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

        let archive = tmp.appendingPathComponent("toolchain.tar.gz")

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["bash", "-c", "tar -C \(tmp.path) -czf \(archive.path) \(toolchainDir.lastPathComponent)"]

        try task.run()
        task.waitUntilExit()

        return try Data(contentsOf: archive)
    }
}
