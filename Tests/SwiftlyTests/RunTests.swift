import Foundation
@testable import Swiftly
@testable import SwiftlyCore
import Testing

@Suite struct RunTests {
    static let homeName = "runTests"

    /// Tests that the `run` command can switch between installed toolchains.
    @Test func runSelection() async throws {
        try await SwiftlyTests.withMockedHome(homeName: Self.homeName, toolchains: SwiftlyTests.allToolchains) {
            // GIVEN: a set of installed toolchains
            // WHEN: invoking the run command with a selector argument for that toolchain
            var output = try await SwiftlyTests.runWithMockedIO(Run.self, ["run", "swift", "--version", "+\(SwiftlyTests.newStable.name)"])
            // THEN: the output confirms that it ran with the selected toolchain
            #expect(output.contains(SwiftlyTests.newStable.name))

            // GIVEN: a set of installed toolchains and one is selected with a .swift-version file
            let versionFile = SwiftlyTests.ctx.currentDirectory.appendingPathComponent(".swift-version")
            try SwiftlyTests.oldStable.name.write(to: versionFile, atomically: true, encoding: .utf8)
            // WHEN: invoking the run command without any selector arguments for toolchains
            output = try await SwiftlyTests.runWithMockedIO(Run.self, ["run", "swift", "--version"])
            // THEN: the output confirms that it ran with the selected toolchain
            #expect(output.contains(SwiftlyTests.oldStable.name))

            // GIVEN: a set of installed toolchains
            // WHEN: invoking the run command with a selector argument for a toolchain that isn't installed
            do {
                try await SwiftlyTests.runCommand(Run.self, ["run", "swift", "+1.2.3", "--version"])
                #expect(false)
            } catch let e as SwiftlyError {
                #expect(e.message.contains("didn't match any of the installed toolchains"))
            }
            // THEN: an error is shown because there is no matching toolchain that is installed
        }
    }

    /// Tests the `run` command verifying that the environment is as expected
    @Test func runEnvironment() async throws {
        try await SwiftlyTests.withMockedHome(homeName: Self.homeName, toolchains: SwiftlyTests.allToolchains) {
            // The toolchains directory should be the fist entry on the path
            let output = try await SwiftlyTests.runWithMockedIO(Run.self, ["run", try await Swiftly.currentPlatform.getShell(), "-c", "echo $PATH"])
            #expect(output.count == 1)
            #expect(output[0].contains(Swiftly.currentPlatform.swiftlyToolchainsDir(SwiftlyTests.ctx).path))
        }
    }

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

        do {
            let _ = try Run.extractProxyArguments(command: ["+1.2.3"])
            #expect(false)
        } catch {}

        do {
            let _ = try Run.extractProxyArguments(command: [])
            #expect(false)
        } catch {}

        (command, selector) = try Run.extractProxyArguments(command: ["swift", "+1.2.3", "build"])
        #expect(["swift", "build"] == command)
        #expect(try! ToolchainSelector(parsing: "1.2.3") == selector)

        (command, selector) = try Run.extractProxyArguments(command: ["swift", "build"])
        #expect(["swift", "build"] == command)
        #expect(nil == selector)
    }
}
