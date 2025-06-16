import ArgumentParser
import Foundation
@testable import SwiftlyCore
import Testing

/// Test actor for capturing output from SwiftlyCoreContext functions
actor TestOutputCapture: OutputHandler {
    private(set) var outputLines: [String] = []

    func handleOutputLine(_ string: String) {
        self.outputLines.append(string)
    }

    func getOutput() -> [String] {
        self.outputLines
    }

    func clearOutput() {
        self.outputLines.removeAll()
    }
}

/// Mock Terminal for testing
struct MockTerminal: Terminal {
    func width() -> Int {
        80 // Default terminal width for testing
    }
}

@Suite struct SwiftlyCoreContextTests {
    @Test func testMessageText() async throws {
        let handler = TestOutputCapture()
        var context = SwiftlyCoreContext(format: .text)
        context.outputHandler = handler

        await context.message("test message")

        let output = await handler.getOutput()
        #expect(output.count == 1)
        #expect(output[0].contains("test message"))
    }

    @Test func testMessageJSON() async throws {
        let errorHandler = TestOutputCapture()
        var context = SwiftlyCoreContext(format: .json)
        context.errorOutputHandler = errorHandler

        await context.message("test message")

        let output = await errorHandler.getOutput()
        #expect(output.count == 1)
        #expect(output[0].contains("test message"))
    }

    @Test func testMessageCustomTerminator() async throws {
        let handler = TestOutputCapture()
        var context = SwiftlyCoreContext(format: .text)
        context.outputHandler = handler

        await context.message("test message", terminator: "!")

        let output = await handler.getOutput()
        #expect(output.count == 1)
        #expect(output[0].contains("test message"))
        #expect(output[0].hasSuffix("!"))
    }

    @Test func testMessageTextWrapping() async throws {
        let handler = TestOutputCapture()
        var context = SwiftlyCoreContext(format: .text)
        context.outputHandler = handler
        context.terminal = MockTerminal()

        // Create a very long message that should be wrapped
        let longMessage = String(repeating: "a ", count: 50)
        await context.message(longMessage)

        let output = await handler.getOutput()
        #expect(output.count == 1)
        #expect(output[0] == String(repeating: "a ", count: 39) + "a\n" + String(repeating: "a ", count: 10))
    }
}
