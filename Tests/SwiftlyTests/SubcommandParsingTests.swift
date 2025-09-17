import ArgumentParser
@testable import Swiftly
import Testing

// Test for simple mistakes declaring options and arguments in subcommands
// that only show up at runtime. For example, a non-optional type for an
// @Option will produce an error "Replace with a static variable, or let constant."
@Suite struct SubcommandParsingTests {
    @Test func selfUpdateParse() throws {
        try SelfUpdate.parse([])
    }
}
