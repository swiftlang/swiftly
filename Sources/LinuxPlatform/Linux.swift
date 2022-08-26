import Foundation
import SwiftlyCore
import SWCompression
import Gzip

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

    public var fullName: String {
        self.platform.fullName
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
        // check if file exists
        guard tmpFile.fileExists() else {
            fatalError("\(tmpFile) doesn't exist")
        }

        // ensure ~/.swiftly/toolchains exists
        let toolchainsDir = swiftlyHomeDir.appendingPathComponent("toolchains")
        if !toolchainsDir.fileExists() {
            try FileManager.default.createDirectory(at: toolchainsDir, withIntermediateDirectories: false)
        }

        // extract files
        print("Extracting toolchain...")
        let gzData = try Data(contentsOf: tmpFile)
        let tarData = try gzData.gunzipped()
        let tarEntries = try TarContainer.open(container: tarData)

        let toolchainDir = toolchainsDir.appendingPathComponent(version.name)
        for entry in tarEntries {
            let relativePath = entry.info.name.drop { c in c != "/" }.dropFirst()
            let fileURL = toolchainDir.appendingPathComponent(String(relativePath))

            if let data = entry.data {
                try data.write(to: fileURL, options: .atomic)

                if let permissions = entry.info.permissions {
                    try FileManager.default.setAttributes(
                        [.posixPermissions: permissions.rawValue],
                        ofItemAtPath: fileURL.path
                    )
                }
            } else {
                try FileManager.default.createDirectory(at: fileURL, withIntermediateDirectories: true)
            }
        }

        // copy to ~/.swiftly/toolchains/<name>
        // if config doesn't have an active toolchain, set it to that
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
        return URL(fileURLWithPath: "/tmp/swiftly-\(UUID())")
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
