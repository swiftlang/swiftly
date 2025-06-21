import Foundation
@testable import Swiftly
@testable import SwiftlyCore
import SystemPackage
import Testing

@Suite("JsonFileProgressReporter Tests")
struct JsonFileProgressReporterTests {
    @Test("Test update method writes progress to file")
    func testUpdateWritesProgressToFile() throws {
        let tempFile = fs.mktemp(ext: ".json")
        let reporter = JsonFileProgressReporter(filePath: tempFile)

        reporter.update(step: 1, total: 10, text: "Processing item 1")

        let fileContent = try String(contentsOfFile: tempFile.string)

        #expect(fileContent.contains("Processing item 1"))
        #expect(fileContent.contains("\"percent\":10"))
        #expect(fileContent.contains("\"step\""))
        #expect(fileContent.contains("\"timestamp\""))

        try FileManager.default.removeItem(atPath: tempFile.string)
    }

    @Test("Test complete method writes completion status")
    func testCompleteWritesCompletionStatus() throws {
        let tempFile = fs.mktemp(ext: ".json")
        let reporter = JsonFileProgressReporter(filePath: tempFile)

        reporter.complete(success: true)

        let fileContent = try String(contentsOfFile: tempFile.string)

        #expect(fileContent.contains("\"success\":true"))
        #expect(fileContent.contains("\"complete\""))

        try FileManager.default.removeItem(atPath: tempFile.string)
    }

    @Test("Test complete method writes failure status")
    func testCompleteWritesFailureStatus() throws {
        let tempFile = fs.mktemp(ext: ".json")
        let reporter = JsonFileProgressReporter(filePath: tempFile)

        reporter.complete(success: false)

        let fileContent = try String(contentsOfFile: tempFile.string)

        #expect(fileContent.contains("\"success\":false"))
        #expect(fileContent.contains("\"complete\""))

        try FileManager.default.removeItem(atPath: tempFile.string)
    }

    @Test("Test percentage calculation")
    func testPercentageCalculation() throws {
        let tempFile = fs.mktemp(ext: ".json")
        let reporter = JsonFileProgressReporter(filePath: tempFile)

        reporter.update(step: 25, total: 100, text: "Quarter way")

        let fileContent = try String(contentsOfFile: tempFile.string)

        #expect(fileContent.contains("\"percent\":25"))

        try FileManager.default.removeItem(atPath: tempFile.string)
    }

    @Test("Test clear method removes file")
    func testClearRemovesFile() throws {
        let tempFile = fs.mktemp(ext: ".json")
        let reporter = JsonFileProgressReporter(filePath: tempFile)

        reporter.update(step: 1, total: 2, text: "Test")

        #expect(FileManager.default.fileExists(atPath: tempFile.string))

        reporter.clear()

        #expect(!FileManager.default.fileExists(atPath: tempFile.string))
    }

    @Test("Test multiple progress updates create multiple lines")
    func testMultipleUpdatesCreateMultipleLines() throws {
        let tempFile = fs.mktemp(ext: ".json")
        let reporter = JsonFileProgressReporter(filePath: tempFile)

        reporter.update(step: 1, total: 3, text: "Step 1")
        reporter.update(step: 2, total: 3, text: "Step 2")
        reporter.complete(success: true)

        let fileContent = try String(contentsOfFile: tempFile.string)
        let lines = fileContent.components(separatedBy: .newlines).filter { !$0.isEmpty }

        #expect(lines.count == 3)
        #expect(lines[0].contains("Step 1"))
        #expect(lines[1].contains("Step 2"))
        #expect(lines[2].contains("\"success\":true"))

        try FileManager.default.removeItem(atPath: tempFile.string)
    }

    @Test("Test zero step edge case")
    func testZeroStepEdgeCase() throws {
        let tempFile = fs.mktemp(ext: ".json")
        let reporter = JsonFileProgressReporter(filePath: tempFile)

        reporter.update(step: 0, total: 10, text: "Starting")

        let fileContent = try String(contentsOfFile: tempFile.string)

        #expect(fileContent.contains("\"percent\":0"))
        #expect(fileContent.contains("Starting"))

        try FileManager.default.removeItem(atPath: tempFile.string)
    }

    @Test("Test full completion edge case")
    func testFullCompletionEdgeCase() throws {
        let tempFile = fs.mktemp(ext: ".json")
        let reporter = JsonFileProgressReporter(filePath: tempFile)

        reporter.update(step: 100, total: 100, text: "Done")

        let fileContent = try String(contentsOfFile: tempFile.string)

        #expect(fileContent.contains("\"percent\":100"))
        #expect(fileContent.contains("Done"))

        try FileManager.default.removeItem(atPath: tempFile.string)
    }
}
