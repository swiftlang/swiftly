import ArgumentParser
import Foundation

public enum OutputFormat: String, Sendable, CaseIterable, ExpressibleByArgument {
    case text
    case json

    public var description: String {
        self.rawValue
    }
}

public protocol OutputFormatter {
    func format(_ data: OutputData) -> String
}

public protocol OutputData: Codable, CustomStringConvertible {
    var description: String { get }
}

public struct TextOutputFormatter: OutputFormatter {
    public init() {}

    public func format(_ data: OutputData) -> String {
        data.description
    }
}

public struct JSONOutputFormatter: OutputFormatter {
    public init() {}

    public func format(_ data: OutputData) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let jsonData = try? encoder.encode(data)

        guard let jsonData = jsonData, let result = String(data: jsonData, encoding: .utf8) else {
            return "{}"
        }

        return result
    }
}
