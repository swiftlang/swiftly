import _StringProcessing
import Foundation

/// Struct modeling a version of swiftly itself.
public struct SwiftlyVersion: Equatable, Comparable, CustomStringConvertible, Sendable {
    /// Regex matching versions like "a.b.c", "a.b.c-alpha", and "a.b.c-alpha2".
    public static func regex() -> Regex<(Substring, Substring, Substring, Substring, Substring?)> {
        try! Regex("^(\\d+)\\.(\\d+)\\.(\\d+)(?:-([a-zA-Z0-9]+))?$")
    }

    public let major: Int
    public let minor: Int
    public let patch: Int
    public let suffix: String?

    public init(major: Int, minor: Int, patch: Int, suffix: String? = nil) {
        self.major = major
        self.minor = minor
        self.patch = patch
        self.suffix = suffix
    }

    public init(parsing tag: String) throws {
        guard let match = try Self.regex().wholeMatch(in: tag) else {
            throw SwiftlyError(message: "unable to parse release tag: \"\(tag)\"")
        }

        self.major = Int(match.output.1)!
        self.minor = Int(match.output.2)!
        self.patch = Int(match.output.3)!
        self.suffix = match.output.4.flatMap(String.init)
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.major != rhs.major {
            return lhs.major < rhs.major
        } else if lhs.minor != rhs.minor {
            return lhs.minor < rhs.minor
        } else if lhs.patch != rhs.patch {
            return lhs.patch < rhs.patch
        } else {
            switch (lhs.suffix, rhs.suffix) {
            case (.none, .some):
                return false
            case (.some, .none):
                return true
            case let (.some(lhsSuffix), .some(rhsSuffix)):
                return lhsSuffix < rhsSuffix
            case (.none, .none):
                return false
            }
        }
    }

    public var description: String {
        var base = "\(self.major).\(self.minor).\(self.patch)"
        if let suffix = self.suffix {
            base += "-\(suffix)"
        }
        return base
    }
}

extension SwiftlyVersion: Decodable {
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let s = try c.decode(String.self)
        let v = try SwiftlyVersion(parsing: s)
        self.major = v.major
        self.minor = v.minor
        self.patch = v.patch
        self.suffix = v.suffix
    }
}

extension SwiftlyVersion: Encodable {
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(self.description)
    }
}
