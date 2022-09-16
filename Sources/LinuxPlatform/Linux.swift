import Foundation
import SwiftlyCore

/// `Platform` implementation for Linux systems.
/// This implementation can be reused for any supported Linux platform.
/// TODO: replace dummy implementations
public struct Linux: Platform {
    private let platform: Config.PlatformDefinition

    public init(platform: Config.PlatformDefinition) {
        self.platform = platform
    }

    public var name: String {
        self.platform.name
    }

    public var nameFull: String {
        self.platform.nameFull
    }

    public var namePretty: String {
        self.platform.namePretty
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

        let toolchainsDir = swiftlyHomeDir.appendingPathComponent("toolchains")
        if !toolchainsDir.fileExists() {
            try FileManager.default.createDirectory(at: toolchainsDir, withIntermediateDirectories: false)
        }

        print("Extracting toolchain...")
        let toolchainDir = toolchainsDir.appendingPathComponent(version.name)

        if toolchainDir.fileExists() {
            try FileManager.default.removeItem(at: toolchainDir)
        }

        try extractArchive(atPath: tmpFile) { name in
            // drop swift-a.b.c-RELEASE etc name from the extracted files.
            let relativePath = name.drop { c in c != "/" }.dropFirst()

            // prepend ~/.swiftly/toolchains/<toolchain> to each file name
            return toolchainDir.appendingPathComponent(String(relativePath))
        }

        // TODO: if config doesn't have an active toolchain, set it to that
    }

    public func uninstall(version _: ToolchainVersion) throws {}

    public func use(_: ToolchainVersion) throws {}

    public func listToolchains(selector _: ToolchainSelector?) -> [ToolchainVersion] {
        []
    }

    public func listAvailableSnapshots(version _: String?) async -> [Snapshot] {
        []
    }

    public func selfUpdate() async throws {}

    public func currentToolchain() throws -> ToolchainVersion? { nil }

    public func getTempFilePath() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("swiftly-\(UUID())")
    }

    public static let currentPlatform: any Platform = {
        do {
            let config = try Config.load()
            return Linux(platform: config.platform)
        } catch {
            fatalError("error loading config: \(error)")
        }
    }()
}
