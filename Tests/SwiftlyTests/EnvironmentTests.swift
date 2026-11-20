import ArgumentParser
import Foundation
import Subprocess
@testable import Swiftly
@testable import SwiftlyCore
import SystemPackage
import Testing
#if canImport(Darwin)
import Darwin
#endif

/// Tests that read or mutate process-wide environment variables (`TOOLCHAINS`, `DEVELOPER_DIR`, ...).
/// These tests modify global mutable state that conflicts with eachother so
/// they must run serially.
@Suite(.serialized) struct EnvironmentTests {
    /// Tests that the `run` command can switch between installed toolchains.
    @Test(.mockedSwiftlyVersion(), .mockHomeToolchains()) func runSelection() async throws {
#if os(macOS)
        // Prevent platform environment variable from affecting the tests
        unsetenv("TOOLCHAINS")
        unsetenv("DEVELOPER_DIR")
#endif

        // GIVEN: a set of installed toolchains
        // WHEN: invoking the run command with a selector argument for that toolchain
        var output = try await SwiftlyTests.runWithMockedIO(Run.self, ["run", "swift", "--version", "+\(ToolchainVersion.newStable.name)"])
        // THEN: the output confirms that it ran with the selected toolchain
        #expect(output.contains(ToolchainVersion.newStable.name))

        // GIVEN: a set of installed toolchains and one is selected with a .swift-version file
        let versionFile = SwiftlyTests.ctx.currentDirectory / ".swift-version"
        try ToolchainVersion.oldStable.name.write(to: versionFile, atomically: true, encoding: .utf8)
        // WHEN: invoking the run command without any selector arguments for toolchains
        output = try await SwiftlyTests.runWithMockedIO(Run.self, ["run", "swift", "--version"])
        // THEN: the output confirms that it ran with the selected toolchain
        #expect(output.contains(ToolchainVersion.oldStable.name))

        // GIVEN: a set of installed toolchains
        // WHEN: invoking the run command with a selector argument for a toolchain that isn't installed
        do {
            try await SwiftlyTests.runCommand(Run.self, ["run", "swift", "+1.2.3", "--version"])
            Issue.record("This was expected to fail with an error because the toolchain isn't installed")
        } catch let e as SwiftlyError {
            #expect(e.message.contains("didn't match any of the installed toolchains"))
        }
        // THEN: an error is shown because there is no matching toolchain that is installed
    }

    /// Tests the `run` command verifying that the environment is as expected
    @Test(.mockedSwiftlyVersion(), .mockHomeToolchains()) func runEnvironment() async throws {
#if os(macOS)
        // Prevent platform environment variable from affecting the tests
        unsetenv("TOOLCHAINS")
        unsetenv("DEVELOPER_DIR")
#endif

        // The toolchains directory should be the fist entry on the path
        let output = try await SwiftlyTests.runWithMockedIO(Run.self, ["run", try await Swiftly.currentPlatform.getShell(), "-c", "echo $PATH"])
        guard output.count == 1 else {
            Issue.record("Expecting one line of output: \(output)")
            return
        }
        #expect(output[0].contains(Swiftly.currentPlatform.swiftlyToolchainsDir(SwiftlyTests.ctx).string))
    }

#if os(macOS)
    /// Tests that `_SWIFTLY_SKIP_ENVIRONMENT_CHECK=1` opts out of the `TOOLCHAINS` conflict check
    /// and leaves `TOOLCHAINS` alone, while any other value keeps the check enabled.
    @Test(.mockedSwiftlyVersion(), .mockHomeToolchains()) func runSkipEnvironmentCheck() async throws {
        let skipVar = "_SWIFTLY_SKIP_ENVIRONMENT_CHECK"
        let conflicting = "org.swift.conflicting.toolchain"

        unsetenv("DEVELOPER_DIR")
        unsetenv(skipVar)
        setenv("TOOLCHAINS", conflicting, 1)
        defer {
            unsetenv("TOOLCHAINS")
            unsetenv(skipVar)
        }

        let command = ["run", try await Swiftly.currentPlatform.getShell(), "-c", "echo $TOOLCHAINS"]

        // GIVEN: a TOOLCHAINS value that conflicts with the selected toolchain, and no opt-out
        // WHEN: running a command
        // THEN: the environment check rejects it
        do {
            try await SwiftlyTests.runCommand(Run.self, command)
            Issue.record("Expected a conflicting TOOLCHAINS to be rejected")
        } catch let e as SwiftlyError {
            #expect(e.message.contains("TOOLCHAINS"))
        }

        // GIVEN: an opt-out value that isn't "1"
        // THEN: the check is still enforced
        setenv(skipVar, "0", 1)
        do {
            try await SwiftlyTests.runCommand(Run.self, command)
            Issue.record("Expected \(skipVar)=0 to keep the check enabled")
        } catch let e as SwiftlyError {
            #expect(e.message.contains("TOOLCHAINS"))
        }

        // GIVEN: the opt-out is set to "1"
        // WHEN: running a command
        // THEN: it succeeds and the caller's TOOLCHAINS is passed through untouched
        setenv(skipVar, "1", 1)
        let output = try await SwiftlyTests.runWithMockedIO(Run.self, command)
        #expect(output == [conflicting])
    }
#endif

#if os(macOS) || os(Linux)
    @Test(
        .mockedSwiftlyVersion(),
        .mockHomeToolchains(),
        arguments: [
            "/a/b/c:SWIFTLY_BIN_DIR:/d/e/f",
            "SWIFTLY_BIN_DIR:/abcde",
            "/defgh:SWIFTLY_BIN_DIR",
            "/xyzabc:/1/3/4",
            "",
        ]
    ) func proxyEnv(_ path: String) async throws {
#if os(macOS)
        // Prevent platform environment variable from affecting the tests
        unsetenv("TOOLCHAINS")
        unsetenv("DEVELOPER_DIR")
#endif

        // GIVEN: a PATH that may contain the swiftly bin directory
        let env: Environment = .custom(["PATH": path.replacing("SWIFTLY_BIN_DIR", with: Swiftly.currentPlatform.swiftlyBinDir(SwiftlyTests.ctx).string)])

        // WHEN: proxying to an installed toolchain
        let newEnv = try await Swiftly.currentPlatform.proxyEnvironment(SwiftlyTests.ctx, env: env, toolchain: .newStable)

        // THEN: the toolchain's bin directory is added to the beginning of the PATH
        // #expect(newEnv.description == "")
        #expect(newEnv.description.contains("PATH: \"\((try await Swiftly.currentPlatform.findToolchainLocation(SwiftlyTests.ctx, .newStable)) / "usr/bin"):"))

        // AND: the swiftly bin directory is removed from the PATH
        #expect(!newEnv.description.contains(Swiftly.currentPlatform.swiftlyBinDir(SwiftlyTests.ctx).string))
        #expect(!newEnv.description.contains(Swiftly.currentPlatform.swiftlyBinDir(SwiftlyTests.ctx).string))
    }
#endif
}
