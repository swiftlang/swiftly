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
    func format(_ data: OutputData) throws -> String
}

public protocol OutputData: Encodable, CustomStringConvertible {
    var description: String { get }
}

public struct TextOutputFormatter: OutputFormatter {
    public init() {}

    public func format(_ data: OutputData) -> String {
        data.description
    }
}

public enum OutputFormatterError: Error {
    case encodingError(String)
}

public struct JSONOutputFormatter: OutputFormatter {
    public init() {}

    public func format(_ data: OutputData) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let jsonData = try encoder.encode(data)
        guard let result = String(data: jsonData, encoding: .utf8) else {
            throw OutputFormatterError.encodingError("Failed to encode JSON data as a string in UTF-8.")
        }
        return result
    }
}
