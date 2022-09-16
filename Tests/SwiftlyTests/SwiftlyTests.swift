@testable import Swiftly
@testable import SwiftlyCore
import XCTest
import ArgumentParser
import _StringProcessing

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

    /// Create a fresh swiftly home directory, populate it with a base config, and run the provided closure.
    /// Any swiftly commands executed in the closure will use this new home directory.
    ///
    /// This method requires the SWIFTLY_PLATFORM_NAME, SWIFTLY_PLATFORM_NAME_FULL, and SWIFTLY_PLATFORM_NAME_PRETTY
    /// environment variables to be set.
    ///
    /// The home directory will be deleted after the provided closure has been executed.
    func withTestHome(f: () async throws -> Void) async throws {
        let testHome = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("testHome", isDirectory: true)
        SwiftlyCore.swiftlyHomeDir = testHome

        if SwiftlyCore.swiftlyHomeDir.fileExists() {
            try FileManager.default.removeItem(at: SwiftlyCore.swiftlyHomeDir)
        }
        try FileManager.default.createDirectory(at: SwiftlyCore.swiftlyHomeDir, withIntermediateDirectories: false)
        defer {
            try? FileManager.default.removeItem(at: SwiftlyCore.swiftlyHomeDir)
        }

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

        try await f()
    }
    
    func validateInstalledToolchains(_ toolchains: Set<ToolchainVersion>, description: String) throws {
        let config = try Config.load()

        guard config.installedToolchains == toolchains else {
            throw SwiftlyTestError(message: "\(description): expected \(toolchains) but got \(config.installedToolchains)")
        }

        #if os(Linux)
        // Verify that the toolchains on disk correspond to those in the config.

        let stableRegex: Regex<(Substring, Substring)> =
            try! Regex("swift-([^-]+)-RELEASE")

        for toolchain in toolchains {
            let toolchainDir = SwiftlyCore.swiftlyHomeDir
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
            } else {
                fatalError("TODO: snapshot version parsing")
            }

            XCTAssertEqual(actualVersion, toolchain)
        }
        #endif
    }

}
