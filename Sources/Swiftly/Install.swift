import _StringProcessing
import ArgumentParser
import AsyncHTTPClient
import Foundation

struct Install: AsyncParsableCommand {
    @Argument(help: "The version of the toolchain to install.")
    var version: String

    mutating func run() async throws {
        let toolchainVersion = try await ToolchainVersion.resolve(version)
        print("installing \(toolchainVersion)")
    }
}

enum ToolchainVersion {
    enum SnapshotBranch {
        case main
        case release(major: Int, minor: Int)
    }

    case stable(major: Int, minor: Int, patch: Int)
    case snapshot(branch: SnapshotBranch, date: String)

    static let versionResolvers: [any ToolchainVersionResolver] = [
        StableVersionResolver(),
        ReleaseSnapshotResolver(),
        MainSnapshotResolver(),
    ]

    static func resolve(_ version: String) async throws -> ToolchainVersion {
        for resolver in Self.versionResolvers {
            guard let resolvedVersion = try await resolver.resolve(version: version) else {
                continue
            }
            return resolvedVersion
        }
        throw Error(message: "invalid version specification: \"\(version)\"")
    }
}

extension ToolchainVersion: CustomStringConvertible {
    var description: String {
        switch self {
        case let .stable(major, minor, patch):
            return "\(major).\(minor).\(patch)"
        case let .snapshot(.main, date):
            return "main-snapshot-\(date)"
        case let .snapshot(.release(major, minor), date):
            return "\(major).\(minor)-snapshot-\(date)"
        }
    }
}

protocol ToolchainVersionResolver {
    func resolve(version: String) async throws -> ToolchainVersion?
}

/// Resolver for matching versions like the following:
///    - a.b.c
///    - a.b
///
/// If a patch version (the ".c" above) is omitted, a network lookup will be performed
/// to resolve the version to the latest patch release associated with the given a.b
/// major/minor version pair.
struct StableVersionResolver: ToolchainVersionResolver {
    struct Release: Decodable {
        let name: String
    }

    static let regex: Regex<(Substring, Substring, Substring, Substring?)> = try! Regex("^(\\d+)\\.(\\d+)(?:\\.(\\d+))?$")

    func resolve(version: String) async throws -> ToolchainVersion? {
        guard let matches = try Self.regex.wholeMatch(in: version) else {
            return nil
        }

        let major = Int(matches.1)!
        let minor = Int(matches.2)!

        if let patch = matches.3 {
            return .stable(major: major, minor: minor, patch: Int(patch)!)
        }

        let httpClient = HTTP()
        let releases = try await httpClient.getFromJSON(url: "https://api.github.com/repos/apple/swift/releases", type: [Release].self)

        let release = releases.first { release in
            release.name.contains("\(major).\(minor)")
        }

        guard let release = release else {
            throw Error(message: "No release found matching \(major).\(minor)")
        }

        let parts = release.name.split(separator: " ")[1].split(separator: ".")
        let patch: Int
        if parts.count == 2 {
            patch = 0
        } else {
            patch = Int(parts[2])!
        }

        return .stable(major: major, minor: minor, patch: patch)
    }
}

/// Resolver for versions like the following:
///    - a.b-snapshot-YYYY-mm-dd
///    - a.b-snapshot
///    - a.b-DEVELOPMENT-SNAPSHOT-YYYY-mm-dd-a
///    - a.b-DEVELOPMENT-SNAPSHOT-YYYY-mm-dd
///    - a.b-DEVELOPMENT-SNAPSHOT
///
/// If a date is omitted, a network lookup will be performed to determine the newest
/// snapshot associated with the a.b release.
struct ReleaseSnapshotResolver: ToolchainVersionResolver {
    static let regex: Regex<(Substring, Substring, Substring, Substring?)> =
        try! Regex("^([0-9]+)\\.([0-9]+)-(?:snapshot|DEVELOPMENT-SNAPSHOT)(?:-([0-9]{4}-[0-9]{2}-[0-9]{2}))?(?:-a)?$")

    func resolve(version: String) async throws -> ToolchainVersion? {
        guard let match = try Self.regex.wholeMatch(in: version) else {
            return nil
        }

        let major = Int(match.output.1)!
        let minor = Int(match.output.2)!

        let date: String
        if let d = match.output.3 {
            date = String(d)
        } else {
            // TODO: get latest snapshot associated with release
            throw Error(message: "TODO: get latest snapshot")
        }

        return .snapshot(branch: .release(major: major, minor: minor), date: date)
    }
}

/// Resolver for matching versions like the following:
///    - main-snapshot-YYYY-mm-dd
///    - main-snapshot
///    - swift-DEVELOPMENT-SNAPSHOT-YYYY-mm-dd-a
///    - swift-DEVELOPMENT-SNAPSHOT-YYYY-mm-dd
///    - swift-DEVELOPMENT-SNAPSHOT
///
/// If a date is omitted, a network lookup will be performed to determine the newest
/// main branch snapshot.
struct MainSnapshotResolver: ToolchainVersionResolver {
    static let regex: Regex<(Substring, Substring?)> =
        try! Regex("^(?:main-snapshot|swift-DEVELOPMENT-SNAPSHOT)(?:-([0-9]{4}-[0-9]{2}-[0-9]{2}))?(?:-a)?$")

    func resolve(version: String) async throws -> ToolchainVersion? {
        guard let match = try Self.regex.wholeMatch(in: version) else {
            return nil
        }

        let date: String
        if let d = match.output.1 {
            date = String(d)
        } else {
            // TODO: get latest snapshot associated with release
            throw Error(message: "TODO: get latest snapshot")
        }

        return .snapshot(branch: .main, date: date)
    }
}
