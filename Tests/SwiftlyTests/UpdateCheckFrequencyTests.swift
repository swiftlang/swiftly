import Foundation
import Testing

@testable import Swiftly

@Suite struct UpdateCheckFrequencyTests {
    private func decode(_ json: some Sequence<UInt8>) throws -> Config.UpdateCheckFrequency {
        try JSONDecoder().decode(Config.UpdateCheckFrequency.self, from: Data(json))
    }

    @Test(arguments: [
        #""never""#: .never,
        #""always""#: .always,
        #""default""#: .default,
        #"{"every": 30}"#: .timeBased(.seconds(30)),
    ] as [String: Config.UpdateCheckFrequency])
    func `Decodes string values`(string: String, frequency: Config.UpdateCheckFrequency) throws {
        #expect(try decode(string.utf8) == frequency)
    }

    @Test(arguments: [
        #""sometimes""#,
        #"{"every": 0}"#,
        #"{"every": 1.5}"#
    ])
    func `Rejects invalid values`(string: String) {
        #expect(throws: (any Error).self) {
            try decode(string.utf8)
        }
    }

    @Test(arguments: [
        .never,
        .always,
        .timeBased(.seconds(90))
    ] as [Config.UpdateCheckFrequency])
    func `Round-trips through JSON`(frequency: Config.UpdateCheckFrequency) throws {
        let data = try JSONEncoder().encode(frequency)
        #expect(try decode(data) == frequency)
    }
}
