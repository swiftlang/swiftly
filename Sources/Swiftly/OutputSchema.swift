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
        var message = self.isGlobal ? "The global default toolchain has been set to `\(self.version)`" : "The file `\(self.versionFile ?? ".swift-version")` has been set to `\(self.version)`"
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
