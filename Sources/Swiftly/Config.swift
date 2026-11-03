import Foundation
import SwiftlyCore

/// Struct modelling the config.json file used to track installed toolchains,
/// the current in-use tooolchain, and information about the platform.
///
/// TODO: implement cache
public struct Config: Codable, Equatable, Sendable {
    public var inUse: ToolchainVersion?
    public var installedToolchains: Set<ToolchainVersion>
    public var platform: PlatformDefinition
    public var version: SwiftlyVersion
    public var latestSwiftlyVersion: SwiftlyVersion?
    public var lastSwiftlyVersionCheck: Date?

    init(
        inUse: ToolchainVersion?,
        installedToolchains: Set<ToolchainVersion>,
        platform: PlatformDefinition,
        version: SwiftlyVersion,
        latestSwiftlyVersion: SwiftlyVersion? = nil
    ) {
        self.inUse = inUse
        self.installedToolchains = installedToolchains
        self.platform = platform
        self.version = version
        self.latestSwiftlyVersion = latestSwiftlyVersion
        self.lastSwiftlyVersionCheck = nil
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// Read the config file from disk.
    public static func load(_ ctx: SwiftlyCoreContext) async throws -> Config {
        do {
            let configFile = Swiftly.currentPlatform.swiftlyConfigFile(ctx)
            let data = try await fs.cat(atPath: configFile)
            let config = try Self.makeDecoder().decode(Config.self, from: data)
            return config
        } catch {
            let msg = """
            Could not load swiftly's configuration file at \(Swiftly.currentPlatform.swiftlyConfigFile(ctx)).

            To begin using swiftly you can install it: '\(CommandLine.arguments[0]) init'.
            """
            throw SwiftlyError(message: msg)
        }
    }

    /// Write the contents of this `Config` struct to disk.
    public func save(_ ctx: SwiftlyCoreContext) throws {
        let outData = try Self.makeEncoder().encode(self)
        try outData.write(to: Swiftly.currentPlatform.swiftlyConfigFile(ctx), options: .atomic)
    }

    public func listInstalledToolchains(selector: ToolchainSelector?) -> [ToolchainVersion] {
#if os(macOS)
        let systemToolchains: [ToolchainVersion] = [.xcodeVersion]
#else
        let systemToolchains: [ToolchainVersion] = []
#endif

        guard let selector else {
            return Array(self.installedToolchains) + systemToolchains
        }

        if case .latest = selector {
            var ts: [ToolchainVersion] = []
            if let t = self.installedToolchains.filter({ $0.isStableRelease() }).max() {
                ts.append(t)
            }
            return ts
        }

        return (self.installedToolchains + systemToolchains).filter { toolchain in
            selector.matches(toolchain: toolchain)
        }
    }

    /// Load the config, pass it to the provided closure, and then
    /// save the modified config to disk.
    public static func update(_ ctx: SwiftlyCoreContext, f: (inout Config) throws -> Void) async throws {
        var config = try await Config.load(ctx)
        try f(&config)
        // only save the updates if the prior closure invocation succeeded
        try config.save(ctx)
    }
}

extension Config {
    // Deadline until next update check (1 day)
    static let updateCheckInterval: TimeInterval = 24 * 60 * 60

    /// Returns true when the Swiftly check is due
    func isUpdateCheckDue(now: Date) -> Bool {
        guard let lastCheck = self.lastSwiftlyVersionCheck else { return true }
        return lastCheck.advanced(by: Self.updateCheckInterval) <= now
    }

    /// Update the newest recorded Swiftly version and check datetime
    func updateSwiftlyVersionConfig(
        _ ctx: SwiftlyCoreContext,
        to latest: SwiftlyVersion,
    ) async throws {
        try await Config.update(ctx) { config in
            config.lastSwiftlyVersionCheck = ctx.now()
            config.latestSwiftlyVersion = latest
        }
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
