import _StringProcessing
import ArgumentParser
import Foundation

import SwiftlyCore

struct Install: AsyncParsableCommand {
    @Argument(help: "The version of the toolchain to install.")
    var version: String

    mutating func run() async throws {
        let selector = try ToolchainSelector(parsing: self.version)
        let toolchainVersion = try await self.resolve(selector: selector)
        print("installing \(toolchainVersion)")
    }

    private func getLatestReleases(numberOfReleases n: Int? = nil) async throws -> [GitHubRelease] {
        var url = "https://api.github.com/repos/apple/swift/releases"
        if let n {
            url += "?per_page=\(n)"
        }
        return try await HTTP().getFromJSON(url: url, type: [GitHubRelease].self)
    }

    func resolve(selector: ToolchainSelector) async throws -> ToolchainVersion {
        switch selector {
        case .latest:
            // get the latest stable release
            guard let release = try await self.getLatestReleases(numberOfReleases: 1).first else {
                throw Error(message: "couldnt get latest releases")
            }
            return try .stable(release.parse())

        case let .stable(major, minor, patch):
            if let patch {
                return .stable(ToolchainVersion.StableRelease(major: major, minor: minor, patch: patch))
            }

            // if no patch was provided, perform a network lookup to get the latest patch release
            // of the provided major/minor version pair.
            for release in try await self.getLatestReleases() {
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

        case let .snapshot(branch, date):
            if let date {
                return .snapshot(branch: branch, date: date)
            }
            // TODO: get latest snapshot if no date provided
            throw Error(message: "TODO get latest snapshot")
        }
    }
}

/// Model of a GitHub REST API release object.
private struct GitHubRelease: Decodable {
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
