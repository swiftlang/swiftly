import Foundation

/// Struct modelling the config.json file used to track installed toolchains,
/// the current in-use tooolchain, and information about the platform.
///
/// TODO: implement cache
public struct Config: Codable {
    public struct PlatformDefinition: Codable {
        public let name: String
        public let namePretty: String
    }

    public var inUse: ToolchainVersion?
    public var installedToolchains: [ToolchainVersion]
    public var platform: PlatformDefinition

    // TODO: support other locations
    private static let url = URL(fileURLWithPath: "~/.swiftly/config.json")

    /// Read the config file from disk.
    public static func load() throws -> Config {
        let data = try Data(contentsOf: Config.url)
        return try JSONDecoder().decode(Config.self, from: data)
    }

    /// Write the contents of this `Config` struct to disk.
    public func save() throws {
        let outData = try JSONEncoder().encode(self)
        try outData.write(to: Config.url, options: .atomic)
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
        try container.encode(String(describing: self))
    }
}

extension ToolchainVersion: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let str = try container.decode(String.self)
        self = try ToolchainVersion(parsing: str)
    }
}
