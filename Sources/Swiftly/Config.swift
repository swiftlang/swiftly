import Foundation
import SwiftlyCore

/// Struct modelling the config.json file used to track installed toolchains,
/// the current in-use tooolchain, and information about the platform.
///
/// TODO: implement cache
public struct Config: Codable, Equatable {
    public var inUse: ToolchainVersion?
    public var installedToolchains: Set<ToolchainVersion>
    public var platform: PlatformDefinition
    public var version: SwiftlyVersion?

    internal init(inUse: ToolchainVersion?, installedToolchains: Set<ToolchainVersion>, platform: PlatformDefinition) {
        self.inUse = inUse
        self.installedToolchains = installedToolchains
        self.platform = platform
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        return encoder
    }

    /// Read the config file from disk.
    public static func load() throws -> Config {
        do {
            let data = try Data(contentsOf: Swiftly.currentPlatform.swiftlyConfigFile)
            var config = try JSONDecoder().decode(Config.self, from: data)
            if config.version == nil {
                // Assume that the version of swiftly is 0.3.0 because that is the last
                // unversioned release.
                config.version = try? SwiftlyVersion(parsing: "0.3.0")
            }
            return config
        } catch {
            let msg = """
            Could not load swiftly's configuration file at \(Swiftly.currentPlatform.swiftlyConfigFile.path).

            To begin using swiftly you can install it: '\(CommandLine.arguments[0]) init'.
            """
            throw Error(message: msg)
        }
    }

    /// Write the contents of this `Config` struct to disk.
    public func save() throws {
        let outData = try Self.makeEncoder().encode(self)
        try outData.write(to: Swiftly.currentPlatform.swiftlyConfigFile, options: .atomic)
    }

    public func listInstalledToolchains(selector: ToolchainSelector?) -> [ToolchainVersion] {
        guard let selector else {
            return Array(self.installedToolchains)
        }

        if case .latest = selector {
            var ts: [ToolchainVersion] = []
            if let t = self.installedToolchains.filter({ $0.isStableRelease() }).max() {
                ts.append(t)
            }
            return ts
        }

        return self.installedToolchains.filter { toolchain in
            selector.matches(toolchain: toolchain)
        }
    }

    /// Load the config, pass it to the provided closure, and then
    /// save the modified config to disk.
    public static func update(f: (inout Config) throws -> Void) throws {
        var config = try Config.load()
        try f(&config)
        // only save the updates if the prior closure invocation succeeded
        try config.save()
    }
}

extension ToolchainVersion: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.name)
    }
}

extension ToolchainVersion: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let str = try container.decode(String.self)
        self = try ToolchainVersion(parsing: str)
    }
}
