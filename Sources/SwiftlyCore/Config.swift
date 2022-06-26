import Foundation

public struct Config: Codable {
    public var inUse: ToolchainVersion?
    public var installedToolchains: [ToolchainVersion]

    // TODO: support other locations
    private static let url = URL(fileURLWithPath: "~/.swiftly/config.json")

    public static func load() throws -> Config {
        let data = try Data(contentsOf: Config.url)
        return try JSONDecoder().decode(Config.self, from: data)
    }

    public func save() throws {
        let outData = try JSONEncoder().encode(self)
        try outData.write(to: Config.url, options: .atomic)
    }

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
