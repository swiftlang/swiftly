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

    public var fullName: String {
        self.platform.fullName
    }

    public var namePretty: String {
        self.platform.namePretty
    }

    public func download(version: ToolchainVersion) async throws -> URL {
        // switch version {
        // case let .stable(stableVersion):
        //     let versionString = "\(stableVersion.major).\(stableVersion.minor).\(stableVersion.patch)"
        //     let url = "https://download.swift.org/swift-\(versionString)-release/\(self.name)/swift-\(versionString)-RELEASE/swift-\(versionString)-RELEASE-\(self.platform.fullName).tar.gz"
        //     print("downloading from \(url)")
        //     // throw Error(message: "TODO")
        //     let filename = "\(UUID()).tar.gz"
        //     let tmpFile = "/tmp/\(filename)"
        //     try await HTTP.downloadFile(
        //         url: url,
        //         to: tmpFile,
        //         reportProgress: { _ in
                    
        //         }
        //     )
        //     print("successfully downloaded \(filename)")
        // default:
        //     fatalError("")
        // }
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
            return Linux(platform: config.platform)
        } catch {
            fatalError("error loading config: \(error)")
        }
    }()
}
