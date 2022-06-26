import _StringProcessing

/// Enum representing a toolchain version.
public enum ToolchainVersion {
    public enum SnapshotBranch: Equatable {
        case main
        case release(major: Int, minor: Int)
    }

    public struct StableRelease: Equatable, Comparable {
        public let major: Int
        public let minor: Int
        public let patch: Int

        public init(major: Int, minor: Int, patch: Int) {
            self.major = major
            self.minor = minor
            self.patch = patch
        }

        public static func < (lhs: Self, rhs: Self) -> Bool {
            if lhs.major != rhs.major {
                return lhs.major < rhs.major
            } else if lhs.minor != rhs.minor {
                return lhs.minor < rhs.minor
            } else {
                return lhs.patch < rhs.patch
            }
        }
    }

    case stable(StableRelease)
    case snapshot(branch: SnapshotBranch, date: String)

    public init(major: Int, minor: Int, patch: Int) {
        self = .stable(StableRelease(major: major, minor: minor, patch: patch))
    }
}

extension ToolchainVersion: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .stable(release):
            return "\(release.major).\(release.minor).\(release.patch)"
        case let .snapshot(.main, date):
            return "main-snapshot-\(date)"
        case let .snapshot(.release(major, minor), date):
            return "\(major).\(minor)-snapshot-\(date)"
        }
    }
}

extension ToolchainVersion: Equatable {}

extension ToolchainVersion: Comparable {
    public static func < (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case let (.stable(lhsRelease), .stable(rhsRelease)):
            return lhsRelease < rhsRelease
        case let (.snapshot(.main, lhsDate), .snapshot(branch: .main, rhsDate)):
            return lhsDate < rhsDate
        case let (.snapshot(.release, lhsDate), .snapshot(branch: .release, rhsDate)):
            return lhsDate < rhsDate
        default:
            return false
        }
    }
}

/// Enum modeling a partially or fully supplied selector of a toolchain version.
public enum ToolchainSelector {
    /// Select the latest stable toolchain.
    case latest

    /// Select a specific stable release toolchain.
    ///
    /// If the patch is not provided, this will select the latest patch release
    /// associated with the given major/minor version pair.
    case stable(major: Int, minor: Int, patch: Int?)

    /// Select a snapshot toolchain.
    ///
    /// If the date is not provided, this will select the latest snapshot
    /// associated with the given branch.
    case snapshot(branch: ToolchainVersion.SnapshotBranch, date: String?)

    public init(parsing input: String) throws {
        for parser in parsers {
            guard let selector = try parser.parse(input) else {
                continue
            }
            self = selector
            return
        }

        throw Error(message: "invalid toolchain selector: \"\(input)\"")
    }
}

/// Protocol used to facilitate parsing `ToolchainSelector`s from strings.
protocol ToolchainSelectorParser {
    func parse(_ string: String) throws -> ToolchainSelector?
}

/// List of all the available selector parsers.
private let parsers: [any ToolchainSelectorParser] = [
    StableVersionParser(),
    ReleaseSnapshotParser(),
    MainSnapshotParser()
]

/// Parser for version selectors like the following:
///    - latest
///    - a.b.c
///    - a.b
struct StableVersionParser: ToolchainSelectorParser {
    static let regex: Regex<(Substring, Substring, Substring, Substring?)> = try! Regex("^(\\d+)\\.(\\d+)(?:\\.(\\d+))?$")

    func parse(_ input: String) throws -> ToolchainSelector? {
        if input == "latest" {
            return .latest
        }

        guard let match = try Self.regex.wholeMatch(in: input) else {
            return nil
        }

        let major = Int(match.output.1)!
        let minor = Int(match.output.2)!

        if let patch = match.output.3 {
            guard let patchNumber = Int(patch) else {
                throw Error(message: "invalid patch version: \(patch)")
            }
            return .stable(major: major, minor: minor, patch: patchNumber)
        } else {
            return .stable(major: major, minor: minor, patch: nil)
        }
    }
}

/// Parser for selectors like the following:
///    - a.b-snapshot-YYYY-mm-dd
///    - a.b-snapshot
///    - a.b-DEVELOPMENT-SNAPSHOT-YYYY-mm-dd-a
///    - a.b-DEVELOPMENT-SNAPSHOT-YYYY-mm-dd
///    - a.b-DEVELOPMENT-SNAPSHOT
struct ReleaseSnapshotParser: ToolchainSelectorParser {
    static let regex: Regex<(Substring, Substring, Substring, Substring?)> =
        try! Regex("^([0-9]+)\\.([0-9]+)-(?:snapshot|DEVELOPMENT-SNAPSHOT)(?:-([0-9]{4}-[0-9]{2}-[0-9]{2}))?(?:-a)?$")

    func parse(_ input: String) throws -> ToolchainSelector? {
        guard let match = try Self.regex.wholeMatch(in: input) else {
            return nil
        }

        guard
            let major = Int(match.output.1),
            let minor = Int(match.output.2)
        else {
            throw Error(message: "malformatted version: \(match.output.1).\(match.output.2)")
        }

        return .snapshot(branch: .release(major: major, minor: minor), date: match.output.3.map(String.init))
    }
}

/// Parser for selectors like the following:
///    - main-snapshot-YYYY-mm-dd
///    - main-snapshot
///    - swift-DEVELOPMENT-SNAPSHOT-YYYY-mm-dd-a
///    - swift-DEVELOPMENT-SNAPSHOT-YYYY-mm-dd
///    - swift-DEVELOPMENT-SNAPSHOT
struct MainSnapshotParser: ToolchainSelectorParser {
    static let regex: Regex<(Substring, Substring?)> =
        try! Regex("^(?:main-snapshot|swift-DEVELOPMENT-SNAPSHOT)(?:-([0-9]{4}-[0-9]{2}-[0-9]{2}))?(?:-a)?$")

    func parse(_ input: String) throws -> ToolchainSelector? {
        guard let match = try Self.regex.wholeMatch(in: input) else {
            return nil
        }
        return .snapshot(branch: .main, date: match.output.1.map(String.init))
    }
}
