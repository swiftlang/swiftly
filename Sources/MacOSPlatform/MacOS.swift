import Foundation
import SwiftlyCore

struct SwiftPkgInfo: Codable {
    var CFBundleIdentifier: String
}

/// `Platform` implementation for macOS systems.
public struct MacOS: Platform {
    public init() {}

    public var appDataDirectory: URL {
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)
    }

    public var toolchainFileExtension: String {
        "pkg"
    }

    public func isSystemDependencyPresent(_: SystemDependency) -> Bool {
        // All system dependencies on macOS should be present
        true
    }

    public func verifySystemPrerequisitesForInstall(httpClient: SwiftlyHTTPClient, requireSignatureValidation: Bool) throws {
        // All system prerequisites should be there for macOS
    }

    public func install(from tmpFile: URL, version: ToolchainVersion) throws {
        guard tmpFile.fileExists() else {
            throw Error(message: "\(tmpFile) doesn't exist")
        }

        if !self.swiftlyToolchainsDir.fileExists() {
            try FileManager.default.createDirectory(at: self.swiftlyToolchainsDir, withIntermediateDirectories: false)
        }

        SwiftlyCore.print("Installing package in user home directory...")
        try runProgram("installer", "-pkg", tmpFile.path, "-target", "CurrentUserHomeDirectory")
    }

    public func uninstall(_ toolchain: ToolchainVersion) throws {
        SwiftlyCore.print("Uninstalling package in user home directory...")

        let toolchainDir = self.swiftlyToolchainsDir.appendingPathComponent("\(toolchain.identifier).xctoolchain", isDirectory: true)

        let decoder = PropertyListDecoder()
        let infoPlist = toolchainDir.appendingPathComponent("Info.plist")
        guard let data = try? Data(contentsOf: infoPlist) else {
            throw Error(message: "could not open \(infoPlist)")
        }

        guard let pkgInfo = try? decoder.decode(SwiftPkgInfo.self, from: data) else {
            throw Error(message: "could not decode plist at \(infoPlist)")
        }

        try FileManager.default.removeItem(at: toolchainDir)

        let homedir = ProcessInfo.processInfo.environment["HOME"]!
        try runProgram("pkgutil", "--volume", homedir, "--forget", pkgInfo.CFBundleIdentifier)
    }

    public func listAvailableSnapshots(version _: String?) async -> [Snapshot] {
        []
    }

    public func getExecutableName() -> String {
        #if arch(x86_64)
        let architecture = "x86_64"
        #elseif arch(arm64)
        let architecture = "aarch64"
        #else
        fatalError("Unsupported processor architecture")
        #endif

        return "swiftly-\(architecture)-macos-osx"
    }

    public func currentToolchain() throws -> ToolchainVersion? { nil }

    public func getTempFilePath() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("swiftly-\(UUID()).pkg")
    }

    public func verifySignature(httpClient: SwiftlyHTTPClient, archiveDownloadURL: URL, archive: URL) async throws {
        // No signature verification is required on macOS since the pkg files have their own signing
        //  mechanism and the swift.org downloadables are trusted by stock macOS installations.
    }

    private func runProgram(_ args: String..., quiet: Bool = false) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = args

        if quiet {
            process.standardOutput = nil
            process.standardError = nil
        }

        try process.run()
        // Attach this process to our process group so that Ctrl-C and other signals work
        let pgid = tcgetpgrp(STDOUT_FILENO)
        if pgid != -1 {
            tcsetpgrp(STDOUT_FILENO, process.processIdentifier)
        }
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw Error(message: "\(args.first!) exited with non-zero status: \(process.terminationStatus)")
        }
    }

    public func detectPlatform(disableConfirmation: Bool, platform: String?) async -> PlatformDefinition {
        // No special detection required on macOS platform
        return PlatformDefinition(name: "xcode", nameFull: "osx", namePretty: "macOS")
    }

    public func getSysDepsCommand(with: [SystemDependency], in: PlatformDefinition) -> String? {
        return nil
    }

    public func proxy(_ toolchain: ToolchainVersion, _ command: String, _ arguments: [String]) async throws {
        let process = Process()
        process.executableURL = self.swiftlyToolchainsDir
            .appendingPathComponent(toolchain.identifier + ".xctoolchain", isDirectory: true)
            .appendingPathComponent("usr/bin", isDirectory: true)
            .appendingPathComponent(command, isDirectory: false)
        process.arguments = arguments
        process.standardInput = FileHandle.standardInput

        try process.run()
        // Attach this process to our process group so that Ctrl-C and other signals work
        let pgid = tcgetpgrp(STDOUT_FILENO)
        if pgid != -1 {
            tcsetpgrp(STDOUT_FILENO, process.processIdentifier)
        }
        process.waitUntilExit()

        exit(process.terminationStatus)
    }

    public static let currentPlatform: any Platform = MacOS()
}
