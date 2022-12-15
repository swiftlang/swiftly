import Foundation
import SwiftlyCore

/// `Platform` implementation for Linux systems.
/// This implementation can be reused for any supported Linux platform.
/// TODO: replace dummy implementations
public struct Linux: Platform {
    public init() {}

    public var appDataDirectory: URL {
        if let dir = ProcessInfo.processInfo.environment["XDG_DATA_HOME"] {
            return URL(fileURLWithPath: dir)
        } else {
            return FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".local", isDirectory: true)
                .appendingPathComponent("share", isDirectory: true)
        }
    }

    public var toolchainFileExtension: String {
        "tar.gz"
    }

    public func isSystemDependencyPresent(_: SystemDependency) -> Bool {
        true
    }

    public func install(from tmpFile: URL, version: ToolchainVersion) throws {
        guard tmpFile.fileExists() else {
            throw Error(message: "\(tmpFile) doesn't exist")
        }

        if !self.swiftlyToolchainsDir.fileExists() {
            try FileManager.default.createDirectory(at: self.swiftlyToolchainsDir, withIntermediateDirectories: false)
        }

        SwiftlyCore.print("Extracting toolchain...")
        let toolchainDir = self.swiftlyToolchainsDir.appendingPathComponent(version.name)

        if toolchainDir.fileExists() {
            try FileManager.default.removeItem(at: toolchainDir)
        }

        try extractArchive(atPath: tmpFile) { name in
            // drop swift-a.b.c-RELEASE etc name from the extracted files.
            let relativePath = name.drop { c in c != "/" }.dropFirst()

            // prepend /path/to/swiftlyHomeDir/toolchains/<toolchain> to each file name
            return toolchainDir.appendingPathComponent(String(relativePath))
        }
    }

    public func uninstall(_ toolchain: ToolchainVersion) throws {
        let toolchainDir = self.swiftlyToolchainsDir.appendingPathComponent(toolchain.name)
        try FileManager.default.removeItem(at: toolchainDir)
    }

    public func use(_ toolchain: ToolchainVersion, currentToolchain: ToolchainVersion?) throws {
        let toolchainBinURL = self.swiftlyToolchainsDir
            .appendingPathComponent(toolchain.name, isDirectory: true)
            .appendingPathComponent("usr", isDirectory: true)
            .appendingPathComponent("bin", isDirectory: true)

        // Delete existing symlinks from previously in-use toolchain.
        if let currentToolchain {
            try self.unUse(currentToolchain: currentToolchain)
        }

        for executable in try FileManager.default.contentsOfDirectory(atPath: toolchainBinURL.path) {
            let linkURL = self.swiftlyBinDir.appendingPathComponent(executable)
            let executableURL = toolchainBinURL.appendingPathComponent(executable)

            try linkURL.deleteIfExists()

            try FileManager.default.createSymbolicLink(
                atPath: linkURL.path,
                withDestinationPath: executableURL.path
            )
        }
    }

    public func unUse(currentToolchain: ToolchainVersion) throws {
        let currentToolchainBinURL = self.swiftlyToolchainsDir
            .appendingPathComponent(currentToolchain.name, isDirectory: true)
            .appendingPathComponent("usr", isDirectory: true)
            .appendingPathComponent("bin", isDirectory: true)

        for existingExecutable in try FileManager.default.contentsOfDirectory(atPath: currentToolchainBinURL.path) {
            guard existingExecutable != "swiftly" else {
                continue
            }
            try self.swiftlyBinDir.appendingPathComponent(existingExecutable).deleteIfExists()
        }
    }

    public func listAvailableSnapshots(version _: String?) async -> [Snapshot] {
        []
    }

    public func selfUpdate() async throws {}

    public func currentToolchain() throws -> ToolchainVersion? { nil }

    public func getTempFilePath() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("swiftly-\(UUID())")
    }

    public static let currentPlatform: any Platform = Linux()
}
