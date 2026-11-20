import ArgumentParser
import Foundation
@testable import Swiftly
@testable import SwiftlyCore
import SystemPackage
import Testing
#if canImport(Darwin)
import Darwin
#endif

@Suite struct RunTests {
    static let homeName = "runTests"

    /// Tests the extraction of proxy arguments from the run command arguments.
    @Test func extractProxyArguments() throws {
        var (command, selector) = try Run.extractProxyArguments(command: ["swift", "build"])
        #expect(["swift", "build"] == command)
        #expect(nil == selector)

        (command, selector) = try Run.extractProxyArguments(command: ["swift", "+1.2.3", "build"])
        #expect(["swift", "build"] == command)
        #expect(try! ToolchainSelector(parsing: "1.2.3") == selector)

        (command, selector) = try Run.extractProxyArguments(command: ["swift", "build", "+latest"])
        #expect(["swift", "build"] == command)
        #expect(try! ToolchainSelector(parsing: "latest") == selector)

        (command, selector) = try Run.extractProxyArguments(command: ["+5.6", "swift", "build"])
        #expect(["swift", "build"] == command)
        #expect(try! ToolchainSelector(parsing: "5.6") == selector)

        (command, selector) = try Run.extractProxyArguments(command: ["swift", "++1.2.3", "build"])
        #expect(["swift", "+1.2.3", "build"] == command)
        #expect(nil == selector)

        (command, selector) = try Run.extractProxyArguments(command: ["swift", "++", "+1.2.3", "build"])
        #expect(["swift", "+1.2.3", "build"] == command)
        #expect(nil == selector)

        #expect(throws: SwiftlyError.self) {
            try Run.extractProxyArguments(command: ["+1.2.3"])
        }

        #expect(throws: SwiftlyError.self) {
            try Run.extractProxyArguments(command: [])
        }

        (command, selector) = try Run.extractProxyArguments(command: ["swift", "+1.2.3", "build"])
        #expect(["swift", "build"] == command)
        #expect(try! ToolchainSelector(parsing: "1.2.3") == selector)

        (command, selector) = try Run.extractProxyArguments(command: ["swift", "build"])
        #expect(["swift", "build"] == command)
        #expect(nil == selector)
    }

    /// Tests the help functionality of the `run` command
    @Test(.testHomeMockedToolchain()) func runHelp() async throws {
        // Test --help is handled correctly
        do {
            try await SwiftlyTests.runCommand(Run.self, ["run", "--help"])
            #expect(Bool(false))
        } catch {
            #expect(error is CleanExit)
        }

        // Test -h is handled correctly
        do {
            try await SwiftlyTests.runCommand(Run.self, ["run", "-h"])
            #expect(Bool(false))
        } catch {
            #expect(error is CleanExit)
        }
    }

    /// Tests the version functionality of the `run` command
    @Test(.testHomeMockedToolchain()) func runVersion() async throws {
        // Test --version is handled correctly
        do {
            try await SwiftlyTests.runCommand(Run.self, ["run", "--version"])
            #expect(Bool(false))
        } catch {
            #expect(error is CleanExit)
        }
    }
}
