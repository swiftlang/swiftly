import Foundation
import SystemPackage
import Testing

@testable import Swiftly
@testable import SwiftlyCore

@Suite struct JsonFileProgressReporterTests {
    @Test("Test update method writes progress to file as valid JSONNL")
    func testUpdateWritesProgressToFile() async throws {
        let tempFile = fs.mktemp(ext: ".json")
        try await fs.create(.mode(Int(0o644)), file: tempFile)
        defer { try? FileManager.default.removeItem(atPath: tempFile.string) }
        let reporter = try JsonFileProgressReporter(SwiftlyTests.ctx, filePath: tempFile)

        try await reporter.update(step: 1, total: 10, text: "Processing item 1")
        try reporter.close()

        let decoder = JSONDecoder()

        let info = try String(contentsOfFile: tempFile.string).split(separator: "\n")
            .filter {
                !$0.isEmpty
            }.map {
                try decoder.decode(
                    ProgressInfo.self,
                    from: Data($0.trimmingCharacters(in: .whitespacesAndNewlines).utf8)
                )
            }

        #expect(info.count == 1)

        if case let .step(timestamp, percent, text) = info.first {
            #expect(text == "Processing item 1")
            #expect(percent == 10)
            #expect(timestamp.timeIntervalSince1970 > 0)
        } else {
            Issue.record("Expected step info but got \(info[0])")
            return
        }
    }

    @Test("Test complete method writes completion status")
    func testCompleteWritesCompletionStatus() async throws {
        let tempFile = fs.mktemp(ext: ".json")
        try await fs.create(.mode(Int(0o644)), file: tempFile)
        defer { try? FileManager.default.removeItem(atPath: tempFile.string) }

        let reporter = try JsonFileProgressReporter(SwiftlyTests.ctx, filePath: tempFile)

        let status = Bool.random()
        try await reporter.complete(success: status)
        try reporter.close()

        let decoder = JSONDecoder()

        let info = try String(contentsOfFile: tempFile.string).split(separator: "\n")
            .filter {
                !$0.isEmpty
            }.map {
                try decoder.decode(ProgressInfo.self, from: Data($0.utf8))
            }

        #expect(info.count == 1)

        if case let .complete(success) = info.first {
            #expect(success == status)
        } else {
            Issue.record("Expected completion info but got \(info)")
            return
        }
    }

    @Test("Test percentage calculation")
    func testPercentageCalculation() async throws {
        let tempFile = fs.mktemp(ext: ".json")
        try await fs.create(.mode(Int(0o644)), file: tempFile)
        defer { try? FileManager.default.removeItem(atPath: tempFile.string) }
        let reporter = try JsonFileProgressReporter(SwiftlyTests.ctx, filePath: tempFile)

        try await reporter.update(step: 25, total: 100, text: "Quarter way")
        try reporter.close()

        let decoder = JSONDecoder()
        let info = try String(contentsOfFile: tempFile.string).split(separator: "\n")
            .filter {
                !$0.isEmpty
            }.map {
                try decoder.decode(ProgressInfo.self, from: Data($0.utf8))
            }
        #expect(info.count == 1)
        if case let .step(_, percent, text) = info.first {
            #expect(percent == 25)
            #expect(text == "Quarter way")
        } else {
            Issue.record("Expected step info but got \(info)")
            return
        }

        try FileManager.default.removeItem(atPath: tempFile.string)
    }

    @Test("Test clear method truncates the file")
    func testClearTruncatesFile() async throws {
        let tempFile = fs.mktemp(ext: ".json")
        try await fs.create(.mode(Int(0o644)), file: tempFile)
        defer { try? FileManager.default.removeItem(atPath: tempFile.string) }
        let reporter = try JsonFileProgressReporter(SwiftlyTests.ctx, filePath: tempFile)
        defer { try? reporter.close() }

        reporter.update(step: 1, total: 2, text: "Test")

        #expect(try String(contentsOf: tempFile).lengthOfBytes(using: String.Encoding.utf8) > 0)

        reporter.clear()

        #expect(try String(contentsOf: tempFile).lengthOfBytes(using: String.Encoding.utf8) == 0)
    }

    @Test("Test multiple progress updates create multiple lines")
    func testMultipleUpdatesCreateMultipleLines() async throws {
        let tempFile = fs.mktemp(ext: ".json")
        try await fs.create(.mode(Int(0o644)), file: tempFile)
        defer { try? FileManager.default.removeItem(atPath: tempFile.string) }

        let reporter = try JsonFileProgressReporter(SwiftlyTests.ctx, filePath: tempFile)

        try await reporter.update(step: 5, total: 100, text: "Processing item 5")
        try await reporter.update(step: 10, total: 100, text: "Processing item 10")
        try await reporter.update(step: 50, total: 100, text: "Processing item 50")
        try await reporter.update(step: 100, total: 100, text: "Processing item 100")

        try await reporter.complete(success: true)
        try? reporter.close()

        let decoder = JSONDecoder()
        let info = try String(contentsOfFile: tempFile.string).split(separator: "\n")
            .filter {
                !$0.isEmpty
            }.map {
                try decoder.decode(ProgressInfo.self, from: Data($0.utf8))
            }

        #expect(info.count == 5)

        for (idx, pct) in [5, 10, 50, 100].enumerated() {
            if case let .step(_, percent, text) = info[idx] {
                #expect(text == "Processing item \(pct)")
                #expect(percent == pct)
            } else {
                Issue.record("Expected step info but got \(info[idx])")
                return
            }
        }

        if case let .complete(success) = info[4] {
            #expect(success == true)
        } else {
            Issue.record("Expected completion info but got \(info[4])")
            return
        }
    }
}
