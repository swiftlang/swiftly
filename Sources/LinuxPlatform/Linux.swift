import Foundation
import SwiftlyCore

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

    #if UBUNTU_1804
        public static let currentPlatform: any Platform =
            Linux(name: "ubuntu1804", namePretty: "Ubuntu 18.04")
    #elseif UBUNTU_2004
        public static let currentPlatform: any Platform =
            Linux(name: "ubuntu2004", namePretty: "Ubuntu 20.04")
    #else
        public static let currentPlatform: any Platform = fatalError("No linux distribution specified")
    #endif
}
