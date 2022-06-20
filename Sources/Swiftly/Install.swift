import ArgumentParser
import AsyncHTTPClient
import Foundation

struct Install: AsyncParsableCommand {
    @Argument(help: "The version of the toolchain to install.")
    var version: String

    mutating func run() async throws {
        let toolchainVersion = try await ToolchainVersion.resolve(self.version)
        print("installing \(toolchainVersion)!")
    }
}

enum ToolchainVersion {
    struct Date {
        let year: String
        let month: String
        let day: String
    }

    enum SnapshotBranch {
        case main
        case release(major: Int, minor: Int)
    }

    case stable(major: Int, minor: Int, patch: Int)
    case snapshot(branch: SnapshotBranch, date: Self.Date)

    static let versionResolvers: [ToolchainVersionResolver.Type] = [
        StableVersionParser.self,
        ReleaseDevelopmentSnapshotParser.self,
        MainDevelopmentSnapshotParser.self
    ]

    static func resolve(_ version: String) async throws -> ToolchainVersion {
        for resolver in Self.versionResolvers {
            let regex = try NSRegularExpression(pattern: resolver.regex, options: [])
            let range = NSRange(version.startIndex..<version.endIndex, in: version)
            guard let match = regex.firstMatch(in: version, range: range) else {
                continue
            }
            var groups: [String] = []
            for i in 0..<match.numberOfRanges {
                let range = Range(match.range(at: i), in: version)!
                groups.append(String(version[range]))
            }
            return try await resolver.resolve(captureGroups: groups)
        }

        throw Error(message: "invalid version specification: \"\(version)\"")
    }
}

protocol ToolchainVersionResolver {
    static var regex: String { get }

    static func resolve(captureGroups: [String]) async throws -> ToolchainVersion
}

struct StableVersionParser: ToolchainVersionResolver {
    static let regex: String = "^([0-9]+)\\.([0-9]+)(?:\\.([0-9]+))?$" 

    static func resolve(captureGroups: [String]) async -> ToolchainVersion {
        let major = Int(captureGroups[1])!
        let minor = Int(captureGroups[2])!

        let patch: Int
        if captureGroups.count == 4 {
            patch = Int(captureGroups[3])!
        } else {
            // TODO: use GH rest api to get latest patch release of this release
            patch = 12
        }

        return .stable(major: major, minor: minor, patch: patch)
    }
}

/// Parser for matching versions like the following:
///    - a.b-snapshot-YYYY-mm-dd
///    - a.b-snapshot
///    - a.b-DEVELOPMENT-SNAPSHOT-YYYY-mm-dd-a
///    - a.b-DEVELOPMENT-SNAPSHOT-YYYY-mm-dd
///    - a.b-DEVELOPMENT-SNAPSHOT
struct ReleaseDevelopmentSnapshotParser: ToolchainVersionResolver {
    static let regex: String = "^([0-9]+)\\.([0-9]+)-(?:snapshot|DEVELOPMENT-SNAPSHOT)(?:-([0-9]{4})-([0-9]{2})-([0-9]{2}))?(?:-a)?$"

    static func resolve(captureGroups: [String]) async -> ToolchainVersion {
        print(captureGroups)
        let major = Int(captureGroups[1])!
        let minor = Int(captureGroups[2])!

        var date: ToolchainVersion.Date? = nil
        if captureGroups.count > 3 {
            date = ToolchainVersion.Date(year: captureGroups[3], month: captureGroups[4], day: captureGroups[5])
        } else {
            // TODO: use GH rest api to get latest dev snapshot for this version
        }

        return .snapshot(branch: .release(major: major, minor: minor), date: date!)
    }
}

/// Parser for matching versions like the following:
///    - main-snapshot-YYYY-mm-dd
///    - main-snapshot
///    - swift-DEVELOPMENT-SNAPSHOT-YYYY-mm-dd-a
///    - swift-DEVELOPMENT-SNAPSHOT-YYYY-mm-dd
///    - swift-DEVELOPMENT-SNAPSHOT
struct MainDevelopmentSnapshotParser: ToolchainVersionResolver {
    static let regex: String = "^(?:main-snapshot|swift-DEVELOPMENT-SNAPSHOT)(?:-([0-9]{4})-([0-9]{2})-([0-9]{2}))?(?:-a)?$"

    static func resolve(captureGroups: [String]) async -> ToolchainVersion {
        var date: ToolchainVersion.Date? = nil
        if captureGroups.count > 1 {
            date = ToolchainVersion.Date(year: captureGroups[2], month: captureGroups[3], day: captureGroups[4])
        } else {
            // TODO: use GH rest api to get latest dev snapshot for this version
        }

        return .snapshot(branch: .main, date: date!)
    }
}
