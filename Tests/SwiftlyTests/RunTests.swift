import Foundation
@testable import Swiftly
@testable import SwiftlyCore
import XCTest

final class RunTests: SwiftlyTests {
    static let homeName = "runTests"

    /// Tests that the `run` command can switch between installed toolchains.
    func testRunSelection() async throws {
        try await self.withMockedHome(homeName: Self.homeName, toolchains: Self.allToolchains) {
            // GIVEN: a set of installed toolchains
            // WHEN: invoking the run command with a selector argument for that toolchain
            var run = try self.parseCommand(Run.self, ["run", "swift", "--version", "+\(Self.newStable.name)"])
            var output = try await run.runWithMockedIO()
            // THEN: the output confirms that it ran with the selected toolchain
            XCTAssert(output.contains(Self.newStable.name))

            // GIVEN: a set of installed toolchains and one is selected with a .swift-version file
            let versionFile = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".swift-version")
            try Self.oldStable.name.write(to: versionFile, atomically: true, encoding: .utf8)
            // WHEN: invoking the run command without any selector arguments for toolchains
            run = try self.parseCommand(Run.self, ["run", "swift", "--version"])
            output = try await run.runWithMockedIO()
            // THEN: the output confirms that it ran with the selected toolchain
            XCTAssert(output.contains(Self.oldStable.name))

            // GIVEN: a set of installed toolchains
            // WHEN: invoking the run command with a selector argument for a toolchain that isn't installed
            run = try self.parseCommand(Run.self, ["run", "swift", "+1.2.3", "--version"])
            do {
                try await run.run()
                XCTAssert(false)
            } catch let e as SwiftlyError {
                XCTAssert(e.message.contains("didn't match any of the installed toolchains"))
            }
            // THEN: an error is shown because there is no matching toolchain that is installed
        }
    }

    /// Tests the `run` command verifying that the environment is as expected
    func testRunEnvironment() async throws {
        try await self.withMockedHome(homeName: Self.homeName, toolchains: Self.allToolchains) {
            // The toolchains directory should be the fist entry on the path
            var run = try self.parseCommand(Run.self, ["run", try await Swiftly.currentPlatform.getShell(), "-c", "echo $PATH"])
            let output = try await run.runWithMockedIO()
            XCTAssert(output.count == 1)
            XCTAssert(output[0].contains(Swiftly.currentPlatform.swiftlyToolchainsDir.path))
        }
    }

    /// Tests the extraction of proxy arguments from the run command arguments.
    func testExtractProxyArguments() throws {
        var (command, selector) = try extractProxyArguments(command: ["swift", "build"])
        XCTAssertEqual(["swift", "build"], command)
        XCTAssertEqual(nil, selector)

        (command, selector) = try extractProxyArguments(command: ["swift", "+1.2.3", "build"])
        XCTAssertEqual(["swift", "build"], command)
        XCTAssertEqual(try! ToolchainSelector(parsing: "1.2.3"), selector)

        (command, selector) = try extractProxyArguments(command: ["swift", "build", "+latest"])
        XCTAssertEqual(["swift", "build"], command)
        XCTAssertEqual(try! ToolchainSelector(parsing: "latest"), selector)

        (command, selector) = try extractProxyArguments(command: ["+5.6", "swift", "build"])
        XCTAssertEqual(["swift", "build"], command)
        XCTAssertEqual(try! ToolchainSelector(parsing: "5.6"), selector)

        (command, selector) = try extractProxyArguments(command: ["swift", "++1.2.3", "build"])
        XCTAssertEqual(["swift", "+1.2.3", "build"], command)
        XCTAssertEqual(nil, selector)

        (command, selector) = try extractProxyArguments(command: ["swift", "++", "+1.2.3", "build"])
        XCTAssertEqual(["swift", "+1.2.3", "build"], command)
        XCTAssertEqual(nil, selector)

        do {
            let _ = try extractProxyArguments(command: ["+1.2.3"])
            XCTAssert(false)
        } catch {}

        do {
            let _ = try extractProxyArguments(command: [])
            XCTAssert(false)
        } catch {}

        (command, selector) = try extractProxyArguments(command: ["swift", "+1.2.3", "build"])
        XCTAssertEqual(["swift", "build"], command)
        XCTAssertEqual(try! ToolchainSelector(parsing: "1.2.3"), selector)

        (command, selector) = try extractProxyArguments(command: ["swift", "build"])
        XCTAssertEqual(["swift", "build"], command)
        XCTAssertEqual(nil, selector)
    }
}
