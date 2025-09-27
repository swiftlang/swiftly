import Foundation
import SwiftlyCore

struct LocationInfo: OutputData {
    let path: String

    init(path: String) {
        self.path = path
    }

    var description: String {
        self.path
    }
}

struct ToolchainInfo: OutputData {
    let version: ToolchainVersion
    let source: ToolchainSource?

    var description: String {
        var message = String(describing: self.version)
        if let source = source {
            message += " (\(source.description))"
        }
        return message
    }
}

struct ToolchainSetInfo: OutputData {
    let version: ToolchainVersion
    let previousVersion: ToolchainVersion?
    let isGlobal: Bool
    let versionFile: String?

    var description: String {
        var message =
            self.isGlobal
                ? "The global default toolchain has been set to `\(self.version)`"
                : "The file `\(self.versionFile ?? ".swift-version")` has been set to `\(self.version)`"
        if let previousVersion = previousVersion {
            message += " (was \(previousVersion.name))"
        }

        return message
    }
}

enum ToolchainSource: Codable, CustomStringConvertible {
    case swiftVersionFile(String)
    case globalDefault

    var description: String {
        switch self {
        case let .swiftVersionFile(path):
            return path
        case .globalDefault:
            return "default"
        }
    }
}

private enum ToolchainVersionCodingKeys: String, CodingKey {
    case name
    case type
    case branch
    case major
    case minor
    case patch
    case date
}

struct AvailableToolchainInfo: OutputData {
    let version: ToolchainVersion
    let inUse: Bool
    let isDefault: Bool
    let installed: Bool

    var description: String {
        var message = "\(version)"
        if self.installed {
            message += " (installed)"
        }
        if self.inUse {
            message += " (in use)"
        }
        if self.isDefault {
            message += " (default)"
        }
        return message
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case inUse
        case isDefault
        case installed
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.inUse, forKey: .inUse)
        try container.encode(self.isDefault, forKey: .isDefault)
        try container.encode(self.installed, forKey: .installed)

        // Encode the version as a object
        var versionContainer = container.nestedContainer(
            keyedBy: ToolchainVersionCodingKeys.self, forKey: .version
        )
        try versionContainer.encode(self.version.name, forKey: .name)

        switch self.version {
        case let .stable(release):
            try versionContainer.encode("stable", forKey: .type)
            try versionContainer.encode(release.major, forKey: .major)
            try versionContainer.encode(release.minor, forKey: .minor)
            try versionContainer.encode(release.patch, forKey: .patch)
        case let .snapshot(snapshot):
            try versionContainer.encode("snapshot", forKey: .type)
            try versionContainer.encode(snapshot.date, forKey: .date)
            try versionContainer.encode(snapshot.branch.name, forKey: .branch)

            if let major = snapshot.branch.major,
               let minor = snapshot.branch.minor
            {
                try versionContainer.encode(major, forKey: .major)
                try versionContainer.encode(minor, forKey: .minor)
            }
        case .xcode:
            try versionContainer.encode("system", forKey: .type)
        }
    }
}

struct AvailableToolchainsListInfo: OutputData {
    let toolchains: [AvailableToolchainInfo]
    var selector: ToolchainSelector?

    init(toolchains: [AvailableToolchainInfo], selector: ToolchainSelector? = nil) {
        self.toolchains = toolchains
        self.selector = selector
    }

    private enum CodingKeys: String, CodingKey {
        case toolchains
    }

    var description: String {
        var lines: [String] = []

        if let selector = selector {
            let modifier =
                switch selector
            {
            case let .stable(major, minor, nil):
                if let minor {
                    "Swift \(major).\(minor) release"
                } else {
                    "Swift \(major) release"
                }
            case .snapshot(.main, nil):
                "main development snapshot"
            case let .snapshot(.release(major, minor), nil):
                "\(major).\(minor) development snapshot"
            default:
                "matching"
            }

            let header = "Available \(modifier) toolchains"
            lines.append(header)
            lines.append(String(repeating: "-", count: header.count))
        } else {
            lines.append("Available release toolchains")
            lines.append("----------------------------")
        }

        lines.append(contentsOf: self.toolchains.map(\.description))
        return lines.joined(separator: "\n")
    }
}

struct InstallToolchainInfo: OutputData {
    let version: ToolchainVersion
    let inUse: Bool
    let isDefault: Bool

    init(version: ToolchainVersion, inUse: Bool, isDefault: Bool) {
        self.version = version
        self.inUse = inUse
        self.isDefault = isDefault
    }

    var description: String {
        var message = "\(version)"

        if self.inUse {
            message += " (in use)"
        }
        if self.isDefault {
            message += " (default)"
        }
        return message
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case inUse
        case isDefault
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.inUse, forKey: .inUse)
        try container.encode(self.isDefault, forKey: .isDefault)

        // Encode the version as a object
        var versionContainer = container.nestedContainer(
            keyedBy: ToolchainVersionCodingKeys.self, forKey: .version
        )
        try versionContainer.encode(self.version.name, forKey: .name)

        switch self.version {
        case let .stable(release):
            try versionContainer.encode("stable", forKey: .type)
            try versionContainer.encode(release.major, forKey: .major)
            try versionContainer.encode(release.minor, forKey: .minor)
            try versionContainer.encode(release.patch, forKey: .patch)
        case let .snapshot(snapshot):
            try versionContainer.encode("snapshot", forKey: .type)
            try versionContainer.encode(snapshot.date, forKey: .date)
            try versionContainer.encode(snapshot.branch.name, forKey: .branch)

            if let major = snapshot.branch.major,
               let minor = snapshot.branch.minor
            {
                try versionContainer.encode(major, forKey: .major)
                try versionContainer.encode(minor, forKey: .minor)
            }
        case .xcode:
            try versionContainer.encode("system", forKey: .type)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.inUse = try container.decode(Bool.self, forKey: .inUse)
        self.isDefault = try container.decode(Bool.self, forKey: .isDefault)

        // Decode the version as a object
        let versionContainer = try container.nestedContainer(
            keyedBy: ToolchainVersionCodingKeys.self, forKey: .version
        )
        _ = try versionContainer.decode(String.self, forKey: .name)

        switch try versionContainer.decode(String.self, forKey: .type) {
        case "stable":
            let major = try versionContainer.decode(Int.self, forKey: .major)
            let minor = try versionContainer.decode(Int.self, forKey: .minor)
            let patch = try versionContainer.decode(Int.self, forKey: .patch)
            self.version = .stable(
                ToolchainVersion.StableRelease(major: major, minor: minor, patch: patch))
        case "snapshot":
            let date = try versionContainer.decode(String.self, forKey: .date)
            let branchName = try versionContainer.decode(String.self, forKey: .branch)
            let branchMajor = try? versionContainer.decodeIfPresent(Int.self, forKey: .major)
            let branchMinor = try? versionContainer.decodeIfPresent(Int.self, forKey: .minor)

            // Determine the branch from the decoded data
            let branch: ToolchainVersion.Snapshot.Branch
            if branchName == "main" {
                branch = .main
            } else if let major = branchMajor, let minor = branchMinor {
                branch = .release(major: major, minor: minor)
            } else {
                throw DecodingError.dataCorruptedError(
                    forKey: ToolchainVersionCodingKeys.branch,
                    in: versionContainer,
                    debugDescription: "Invalid branch format: \(branchName)"
                )
            }

            self.version = .snapshot(
                ToolchainVersion.Snapshot(
                    branch: branch,
                    date: date
                ))
        case "system":
            // The only system toolchain that exists at the moment is the xcode version
            self.version = .xcode
        default:
            throw DecodingError.dataCorruptedError(
                forKey: ToolchainVersionCodingKeys.type,
                in: versionContainer,
                debugDescription: "Unknown toolchain type"
            )
        }
    }
}

struct InstalledToolchainsListInfo: OutputData {
    let toolchains: [InstallToolchainInfo]
    var selector: ToolchainSelector?

    private enum CodingKeys: String, CodingKey {
        case toolchains
    }

    var description: String {
        var lines: [String] = []

        if let selector = selector {
            let modifier =
                switch selector
            {
            case let .stable(major, minor, nil):
                if let minor {
                    "Swift \(major).\(minor) release"
                } else {
                    "Swift \(major) release"
                }
            case .snapshot(.main, nil):
                "main development snapshot"
            case let .snapshot(.release(major, minor), nil):
                "\(major).\(minor) development snapshot"
            case .xcode:
                "xcode"
            default:
                "matching"
            }

            let header = "Installed \(modifier) toolchains"
            lines.append(header)
            lines.append(String(repeating: "-", count: header.count))
            lines.append(contentsOf: self.toolchains.map(\.description))
        } else {
            let releaseToolchains = self.toolchains.filter { $0.version.isStableRelease() }
            let snapshotToolchains = self.toolchains.filter { $0.version.isSnapshot() }

            lines.append("Installed release toolchains")
            lines.append("----------------------------")
            lines.append(contentsOf: releaseToolchains.map(\.description))

            lines.append("")
            lines.append("Installed snapshot toolchains")
            lines.append("-----------------------------")
            lines.append(contentsOf: snapshotToolchains.map(\.description))

#if os(macOS)
            lines.append("")
            lines.append("Available system toolchains")
            lines.append("---------------------------")
            lines.append(ToolchainVersion.xcode.description)
#endif
        }

        return lines.joined(separator: "\n")
    }
}

struct InstallInfo: OutputData {
    let version: ToolchainVersion
    let alreadyInstalled: Bool

    init(version: ToolchainVersion, alreadyInstalled: Bool) {
        self.version = version
        self.alreadyInstalled = alreadyInstalled
    }

    var description: String {
        "\(self.version) is \(self.alreadyInstalled ? "already installed" : "installed successfully!")"
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case alreadyInstalled
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.version.name, forKey: .version)
        try container.encode(self.alreadyInstalled, forKey: .alreadyInstalled)
    }
}
