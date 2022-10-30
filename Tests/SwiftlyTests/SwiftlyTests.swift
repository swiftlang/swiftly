import _StringProcessing
import ArgumentParser
@testable import Swiftly
@testable import SwiftlyCore
import XCTest

struct SwiftlyTestError: LocalizedError {
    let message: String
}

class SwiftlyTests: XCTestCase {
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
        let oldHome = Config.swiftlyHomeDir

        let testHome = Self.getTestHomePath(name: name)
        Config.swiftlyHomeDir = testHome
        defer {
            Config.swiftlyHomeDir = oldHome
        }

        if testHome.fileExists() {
            try FileManager.default.removeItem(at: Config.swiftlyHomeDir)
        }
        try FileManager.default.createDirectory(at: Config.swiftlyHomeDir, withIntermediateDirectories: false)

        let getEnv = { varName in
            guard let v = ProcessInfo.processInfo.environment[varName] else {
                throw SwiftlyTestError(message: "environment variable \(varName) must be set in order to run tests")
            }
            return v
        }

        let config = Config(
            inUse: nil,
            installedToolchains: [],
            platform: Config.PlatformDefinition(
                name: try getEnv("SWIFTLY_PLATFORM_NAME"),
                nameFull: try getEnv("SWIFTLY_PLATFORM_NAME_FULL"),
                namePretty: try getEnv("SWIFTLY_PLATFORM_NAME_PRETTY")
            )
        )
        try config.save()
        defer {
            try? FileManager.default.removeItem(at: testHome)
        }

        try await f()
    }

    /// Validates that the provided toolchain is the one currently marked as "in use".
    /// If nil is provided, this validates that no toolchain is currently in use.
    func validateInUse(expected: ToolchainVersion?) async throws {
        let executable = SwiftExecutable(path: Config.swiftlyBinDir.appendingPathComponent("swift"))

        XCTAssertEqual(executable.exists(), expected != nil)

        guard let expected else {
            return
        }

        let inUseVersion = try await executable.version()
        XCTAssertEqual(inUseVersion, expected)
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

        let stableRegex: Regex<(Substring, Substring)> =
            try! Regex("swift-([^-]+)-RELEASE")

        let snapshotRegex: Regex<(Substring, Substring)> =
            try! Regex("\\(LLVM [a-z0-9]+, Swift ([a-z0-9]+)\\)")

        for toolchain in toolchains {
            let toolchainDir = Config.swiftlyHomeDir
                .appendingPathComponent("toolchains")
                .appendingPathComponent(toolchain.name)
            XCTAssertTrue(toolchainDir.fileExists())

            let swiftBinary = toolchainDir
                .appendingPathComponent("usr")
                .appendingPathComponent("bin")
                .appendingPathComponent("swift")

            let process = Process()
            process.executableURL = swiftBinary
            process.arguments = ["--version"]

            let outputPipe = Pipe()
            process.standardOutput = outputPipe

            try process.run()
            process.waitUntilExit()

            guard let outputData = try outputPipe.fileHandleForReading.readToEnd() else {
                XCTFail("got no output from swift binary")
                return
            }

            let outputString = String(decoding: outputData, as: UTF8.self)

            let actualVersion: ToolchainVersion

            if let match = try stableRegex.firstMatch(in: outputString) {
                let versions = match.output.1.split(separator: ".")

                let major = Int(versions[0])!
                let minor = Int(versions[1])!

                let patch: Int
                if versions.count == 3 {
                    patch = Int(versions[2])!
                } else {
                    patch = 0
                }

                actualVersion = ToolchainVersion(major: major, minor: minor, patch: patch)
            } else if let match = try snapshotRegex.firstMatch(in: outputString) {
                let commitHash = match.output.1

                // Get the commit hash from swift --version, look up the corresponding tag via GitHub, and confirm
                // that it matches the expected version.
                guard
                    let tag: GitHubTag = try await HTTP.mapGitHubTags(
                        limit: 1,
                        filterMap: { tag in
                            guard tag.commit!.sha.starts(with: commitHash) else {
                                return nil
                            }
                            return tag
                        },
                        fetch: HTTP.getTags
                    ).first,
                    let snapshot = try tag.parseSnapshot()
                else {
                    XCTFail("could not find tag matching hash \(commitHash)")
                    return
                }

                actualVersion = .snapshot(snapshot)
            } else {
                XCTFail("bad version: \(outputString)")
                return
            }

            XCTAssertEqual(actualVersion, toolchain)
        }
#endif
    }
}

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

        let outputPipe = Pipe()
        process.standardOutput = outputPipe

        try process.run()
        process.waitUntilExit()

        guard let outputData = try outputPipe.fileHandleForReading.readToEnd() else {
            throw SwiftlyTestError(message: "got no output from swift binary at path \(self.path.path)")
        }

        let outputString = String(decoding: outputData, as: UTF8.self)

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
        } else if let match = try Self.snapshotRegex.firstMatch(in: outputString) {
            let commitHash = match.output.1

            // Get the commit hash from swift --version, look up the corresponding tag via GitHub, and confirm
            // that it matches the expected version.
            guard
                let tag: GitHubTag = try await HTTP.mapGitHubTags(
                    limit: 1,
                    filterMap: { tag in
                        guard tag.commit!.sha.starts(with: commitHash) else {
                            return nil
                        }
                        return tag
                    },
                    fetch: HTTP.getTags
                ).first,
                let snapshot = try tag.parseSnapshot()
            else {
                throw SwiftlyTestError(message: "could not find tag matching hash \(commitHash)")
            }

            return .snapshot(snapshot)
        } else {
            throw SwiftlyTestError(message: "bad version: \(outputString)")
        }
    }
}
