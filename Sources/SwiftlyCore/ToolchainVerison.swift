import _StringProcessing

/// Enum representing a fully resolved toolchain version (e.g. 5.6.7 or 5.7-snapshot-2022-07-05).
public enum ToolchainVersion {

    public struct Snapshot: Equatable, Hashable {
        public enum Branch: Equatable, Hashable {
            case main
            case release(major: Int, minor: Int)
        }
        public let branch: Branch
        public let date: String
    }

    public struct StableRelease: Equatable, Comparable, Hashable {
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
    case snapshot(Snapshot)

    public init(major: Int, minor: Int, patch: Int) {
        self = .stable(StableRelease(major: major, minor: minor, patch: patch))
    }

    public init(snapshotBranch: Snapshot.Branch, date: String) {
        self = .snapshot(Snapshot(branch: snapshotBranch, date: date))
    }

    static let stableRegex: Regex<(Substring, Substring, Substring, Substring)> =
        try! Regex("^(\\d+)\\.(\\d+)\\.(\\d+)$")

    static let mainSnapshotRegex: Regex<(Substring, Substring)> =
        try! Regex("^main-snapshot-(\\d{4}-\\d{2}-\\d{2})$")

    static let releaseSnapshotRegex: Regex<(Substring, Substring, Substring, Substring)> =
        try! Regex("^(\\d+)\\.(\\d+)-snapshot-(\\d{4}-\\d{2}-\\d{2})$")

    /// Parse a toolchain version from the provided string.
    public init(parsing string: String) throws {
        if let match = try Self.stableRegex.wholeMatch(in: string) {
            guard
                let major = Int(match.output.1),
                let minor = Int(match.output.2),
                let patch = Int(match.output.3)
            else {
                throw Error(message: "invalid stable version: \(string)")
            }
            self = ToolchainVersion(major: major, minor: minor, patch: patch)
        } else if let match = try Self.mainSnapshotRegex.wholeMatch(in: string) {
            self = ToolchainVersion(snapshotBranch: .main, date: String(match.output.1))
        } else if let match = try Self.releaseSnapshotRegex.wholeMatch(in: string) {
            guard
                let major = Int(match.output.1),
                let minor = Int(match.output.2)
            else {
                throw Error(message: "invalid release snapshot version: \(string)")
            }
            self = ToolchainVersion(snapshotBranch: .release(major: major, minor: minor), date: String(match.output.3))
        } else {
            throw Error(message: "invalid toolchain version: \"\(string)\"")
        }
    }

    public func isStableRelease() -> Bool {
        guard case .stable = self else {
            return false
        }
        return true
    }

    public func isSnapshot() -> Bool {
        guard case .snapshot = self else {
            return false
        }
        return true
    }

    public var name: String {
        switch self {
        case let .stable(release):
            return "\(release.major).\(release.minor).\(release.patch)"
        case let .snapshot(release):
            switch release.branch {
            case .main:
                return "main-snapshot-\(release.date)"
            case let .release(major, minor):
                return "\(major).\(minor)-snapshot-\(release.date)"
            }
        }
    }
}

extension ToolchainVersion: LosslessStringConvertible {
    public init?(_ string: String) {
        guard let v = try? ToolchainVersion(parsing: string) else {
            return nil
        }
        self = v
    }
}

extension ToolchainVersion: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .stable(release):
            return "Swift \(release.major).\(release.minor).\(release.patch)"
        case .snapshot:
            return self.name
        }
    }
}

extension ToolchainVersion: Equatable {}

extension ToolchainVersion: Comparable {
    public static func < (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case let (.stable(lhsRelease), .stable(rhsRelease)):
            return lhsRelease < rhsRelease
        case let (.snapshot(lhsRelease), .snapshot(rhsRelease)):
            return lhsRelease.branch == rhsRelease.branch && lhsRelease.date < rhsRelease.date
        default:
            return false
        }
    }
}

extension ToolchainVersion: Hashable {}

/// Enum modeling a partially or fully supplied selector of a toolchain version.
public enum ToolchainSelector {
    /// Select the latest stable toolchain.
    case latest

    /// Select a specific stable release toolchain.
    ///
    /// If the patch is not provided, this will select the latest patch release
    /// associated with the given major/minor version pair.
    case stable(major: Int, minor: Int?, patch: Int?)

    /// Select a snapshot toolchain.
    ///
    /// If the date is not provided, this will select the latest snapshot
    /// associated with the given branch.
    case snapshot(branch: ToolchainVersion.Snapshot.Branch, date: String?)

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

    public func isReleaseSelector() -> Bool {
        switch self {
        case .latest, .stable:
            return true
        case .snapshot:
            return false
        }
    }

    public func isSnapshotSelector() -> Bool {
        return !self.isReleaseSelector()
    }

    /// Returns whether or not this selector "matches" the provided toolchain.
    public func matches(toolchain: ToolchainVersion) -> Bool {
        switch (self, toolchain) {
        case let (.stable(major, minor, patch), .stable(release)):
            guard release.major == major else {
                return false
            }
            if let minor {
                guard release.minor == minor else {
                    return false
                }
            }
            if let patch {
                guard release.patch == patch else {
                    return false
                }
            }
            return true

        case let (.snapshot(selectorBranch, selectorDate), .snapshot(release)):
            guard selectorBranch == release.branch else {
                return false
            }
            if let selectorDate {
                guard selectorDate == release.date else {
                    return false
                }
            }
            return true

        default:
            return false
        }
    }
}

/// Protocol used to facilitate parsing `ToolchainSelector`s from strings.
protocol ToolchainSelectorParser {
    func parse(_ string: String) throws -> ToolchainSelector?
}

/// List of all the available selector parsers.
private let parsers: [any ToolchainSelectorParser] = [
    StableReleaseParser(),
    ReleaseSnapshotParser(),
    MainSnapshotParser()
]

/// Parser for version selectors like the following:
///    - latest
///    - a.b.c
///    - a.b
struct StableReleaseParser: ToolchainSelectorParser {
    static let regex: Regex<(Substring, Substring, Substring?, Substring?)> =
        try! Regex("^(\\d+)(?:\\.(\\d+))?(?:\\.(\\d+))?$")

    func parse(_ input: String) throws -> ToolchainSelector? {
        if input == "latest" {
            return .latest
        }

        guard let match = try Self.regex.wholeMatch(in: input) else {
            return nil
        }

        let major = Int(match.output.1)!
        let minor = match.output.2.flatMap { Int($0) }
        let patch = match.output.3.flatMap { Int($0) }

        return .stable(major: major, minor: minor, patch: patch)
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
