import Foundation


public var swiftlyHomeDir =
    FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".swiftly", isDirectory: true)

/// Struct modelling the config.json file used to track installed toolchains,
/// the current in-use tooolchain, and information about the platform.
///
/// TODO: implement cache
public struct Config: Codable {
    public struct PlatformDefinition: Codable {
        public let name: String
        public let nameFull: String
        public let namePretty: String
    }

    public var inUse: ToolchainVersion?
    public var installedToolchains: Set<ToolchainVersion>
    public var platform: PlatformDefinition

    // TODO: support other locations
    public static let fileName = "config.json"
    private static let url = swiftlyHomeDir.appendingPathComponent(Self.fileName)

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
        let data = try Data(contentsOf: Config.url)
        return try JSONDecoder().decode(Config.self, from: data)
    }

    /// Write the contents of this `Config` struct to disk.
    public func save() throws {
        let outData = try Self.makeEncoder().encode(self)
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
