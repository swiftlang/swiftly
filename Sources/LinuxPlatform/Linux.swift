import Foundation
import SwiftlyCore

public struct Linux: Platform {
    public let name: String
    public let namePretty: String

    init(name: String, namePretty: String) {
        self.name = name
        self.namePretty = namePretty
    }

    public func download(version _: String) async throws -> URL {
        throw Error(message: "TODO")
    }

    public func isSystemDependencyPresent(_: SystemDependency) -> Bool {
        true
    }

    public func install(from _: URL, version _: String) throws {}

    public func uninstall(version _: String) throws {}

    public func use(version _: String) throws {}

    public func listToolchains(selector _: ToolchainSelector?) -> [ToolchainVersion] {
        []
    }

    public func listAvailableSnapshots(version _: String) async -> [Snapshot] {
        []
    }

    public func selfUpdate() async throws {}
}
