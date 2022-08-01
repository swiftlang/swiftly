import Foundation
import SwiftlyCore

/// `Platform` implementation for Linux systems.
/// This implementation can be reused for any supported Linux platform.
/// TODO: replace dummy implementations
public struct Linux: Platform {
    public let name: String
    public let namePretty: String

    public init(name: String, namePretty: String) {
        self.name = name
        self.namePretty = namePretty
    }

    public func download(version _: ToolchainVersion) async throws -> URL {
        throw Error(message: "TODO")
    }

    public func isSystemDependencyPresent(_: SystemDependency) -> Bool {
        true
    }

    public func install(from _: URL, version _: ToolchainVersion) throws {}

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

    public static let currentPlatform: any Platform = {
        do {
            let config = try Config.load()
            return Linux(name: config.platform.name, namePretty: config.platform.namePretty)
        } catch {
            fatalError("error loading config: \(error)")
        }
    }()
}
