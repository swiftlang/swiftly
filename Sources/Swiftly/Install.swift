import _StringProcessing
import ArgumentParser
import AsyncHTTPClient
import Foundation

struct Install: AsyncParsableCommand {
    @Argument(help: "The version of the toolchain to install.")
    var version: String

    static let versionResolvers: [any ToolchainVersionResolver] = [
        StableVersionResolver(),
        ReleaseSnapshotResolver(),
        MainSnapshotResolver(),
    ]

    mutating func run() async throws {
        let toolchainVersion = try await self.resolve()
        print("installing \(toolchainVersion)")
    }

    func resolve() async throws -> ToolchainVersion {
        for resolver in Self.versionResolvers {
            guard let resolvedVersion = try await resolver.resolve(version: version) else {
                continue
            }
            return resolvedVersion
        }
        throw Error(message: "invalid version specification: \"\(self.version)\"")
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
    /// Model of a GitHub REST API release object.
    struct GitHubRelease: Decodable {
        /// The name of the release.
        /// e.g. "Swift a.b[.c] Release".
        let name: String

        func parse() throws -> ToolchainVersion.StableRelease {
            // names look like Swift a.b.c Release
            let parts = self.name.split(separator: " ")
            guard parts.count >= 2 else {
                throw Error(message: "Malformatted release name from GitHub API: \(self.name)")
            }

            // versions can be a.b.c or a.b for .0 releases
            let versionParts = parts[1].split(separator: ".")
            guard
                versionParts.count >= 2,
                let major = Int(versionParts[0]),
                let minor = Int(versionParts[1])
            else {
                throw Error(message: "Malformatted release version from GitHub API: \(parts[1])")
            }

            let patch: Int
            if versionParts.count == 3 {
                guard let p = Int(versionParts[2]) else {
                    throw Error(message: "Malformatted patch version from GitHub API: \(versionParts[2])")
                }
                patch = p
            } else {
                patch = 0
            }

            return ToolchainVersion.StableRelease(major: major, minor: minor, patch: patch)
        }
    }

    static let regex: Regex<(Substring, Substring, Substring, Substring?)> = try! Regex("^(\\d+)\\.(\\d+)(?:\\.(\\d+))?$")

    func getLatestReleases(numberOfReleases n: Int? = nil) async throws -> [GitHubRelease] {
        var url = "https://api.github.com/repos/apple/swift/releases"
        if let n {
            url += "?per_page=\(n)"
        }
        return try await HTTP().getFromJSON(url: url, type: [GitHubRelease].self)
    }

    func resolve(version: String) async throws -> ToolchainVersion? {
        if version == "latest" {
            guard let release = try await self.getLatestReleases(numberOfReleases: 1).first else {
                return nil
            }
            return try .stable(release.parse())
        }

        guard let matches = try Self.regex.wholeMatch(in: version) else {
            return nil
        }

        let major = Int(matches.1)!
        let minor = Int(matches.2)!

        if let patch = matches.3 {
            return .stable(ToolchainVersion.StableRelease(major: major, minor: minor, patch: Int(patch)!))
        }

        let releases = try await self.getLatestReleases()

        for release in releases {
            let parsed = try release.parse()
            guard
                parsed.major == major,
                parsed.minor == minor
            else {
                continue
            }
            return .stable(parsed)
        }

        throw Error(message: "No release found matching \(major).\(minor)")
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
