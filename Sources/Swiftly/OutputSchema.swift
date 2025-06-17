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
        case `default`
        case installed
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

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.inUse, forKey: .inUse)
        try container.encode(self.isDefault, forKey: .default)
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
        }
    }
}

struct AvailableToolchainsListInfo: OutputData {
    let toolchains: [AvailableToolchainInfo]
    let selector: ToolchainSelector?

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
