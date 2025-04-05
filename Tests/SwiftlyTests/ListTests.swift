import Foundation
@testable import Swiftly
@testable import SwiftlyCore
import Testing

@Suite struct ListTests {
    static let homeName = "useTests"

    static let sortedReleaseToolchains: [ToolchainVersion] = [
        SwiftlyTests.newStable,
        SwiftlyTests.oldStableNewPatch,
        SwiftlyTests.oldStable,
    ]

    static let sortedSnapshotToolchains: [ToolchainVersion] = [
        SwiftlyTests.newMainSnapshot,
        SwiftlyTests.oldMainSnapshot,
        SwiftlyTests.newReleaseSnapshot,
        SwiftlyTests.oldReleaseSnapshot,
    ]

    /// Constructs a mock home directory with the toolchains listed above installed and runs the provided closure within
    /// the context of that home.
    func runListTest(f: () async throws -> Void) async throws {
        try await SwiftlyTests.withTestHome(name: Self.homeName) {
            for toolchain in SwiftlyTests.allToolchains {
                try await SwiftlyTests.installMockedToolchain(toolchain: toolchain)
            }

            try await SwiftlyTests.runCommand(Use.self, ["use", "latest"])

            try await f()
        }
    }

    /// Runs a `list` command with the provided selector and parses the output to return an array of listed toolchains
    /// in the order they were printed to stdout.
    func runList(selector: String?) async throws -> [ToolchainVersion] {
        var args = ["list"]
        if let selector {
            args.append(selector)
        }

        let output = try await SwiftlyTests.runWithMockedIO(List.self, args)

        let parsedToolchains = output.compactMap { outputLine in
            SwiftlyTests.allToolchains.first {
                outputLine.contains(String(describing: $0))
            }
        }

        // Ensure extra toolchains weren't accidentally included in the output.
        guard parsedToolchains.count == output.filter({ $0.hasPrefix("Swift") || $0.contains("-snapshot") }).count else {
            throw SwiftlyTestError(message: "unexpected listed toolchains in \(output)")
        }

        return parsedToolchains
    }

    /// Tests that running `swiftly list` without a selector prints all installed toolchains, sorted in descending
    /// order with release toolchains listed first.
    @Test func list() async throws {
        try await self.runListTest {
            let toolchains = try await self.runList(selector: nil)
            #expect(toolchains == Self.sortedReleaseToolchains + Self.sortedSnapshotToolchains)
        }
    }

    /// Tests that running `swiftly list` with a release version selector filters out unmatching toolchains and prints
    /// in descending order.
    @Test func listReleaseToolchains() async throws {
        try await self.runListTest {
            var toolchains = try await self.runList(selector: "5")
            #expect(toolchains == Self.sortedReleaseToolchains)

            var selector = "\(SwiftlyTests.newStable.asStableRelease!.major).\(SwiftlyTests.newStable.asStableRelease!.minor)"
            toolchains = try await self.runList(selector: selector)
            #expect(toolchains == [SwiftlyTests.newStable])

            selector = "\(SwiftlyTests.oldStable.asStableRelease!.major).\(SwiftlyTests.oldStable.asStableRelease!.minor)"
            toolchains = try await self.runList(selector: selector)
            #expect(toolchains == [SwiftlyTests.oldStableNewPatch, SwiftlyTests.oldStable])

            for toolchain in Self.sortedReleaseToolchains {
                toolchains = try await self.runList(selector: toolchain.name)
                #expect(toolchains == [toolchain])
            }

            toolchains = try await self.runList(selector: "4")
            #expect(toolchains == [])
        }
    }

    /// Tests that running `swiftly list` with a snapshot selector filters out unmatching toolchains and prints
    /// in descending order.
    @Test func listSnapshotToolchains() async throws {
        try await self.runListTest {
            var toolchains = try await self.runList(selector: "main-snapshot")
            #expect(toolchains == [SwiftlyTests.newMainSnapshot, SwiftlyTests.oldMainSnapshot])

            let snapshotBranch = SwiftlyTests.newReleaseSnapshot.asSnapshot!.branch
            toolchains = try await self.runList(selector: "\(snapshotBranch.major!).\(snapshotBranch.minor!)-snapshot")
            #expect(toolchains == [SwiftlyTests.newReleaseSnapshot, SwiftlyTests.oldReleaseSnapshot])

            for toolchain in Self.sortedSnapshotToolchains {
                toolchains = try await self.runList(selector: toolchain.name)
                #expect(toolchains == [toolchain])
            }

            toolchains = try await self.runList(selector: "1.2-snapshot")
            #expect(toolchains == [])
        }
    }

    /// Tests that the "(in use)" marker is correctly printed when listing installed toolchains.
    @Test func listInUse() async throws {
        func inUseTest(toolchain: ToolchainVersion, selector: String?) async throws {
            try await SwiftlyTests.runCommand(Use.self, ["use", toolchain.name])

            var listArgs = ["list"]
            if let selector {
                listArgs.append(selector)
            }

            let output = try await SwiftlyTests.runWithMockedIO(List.self, listArgs)

            let inUse = output.filter { $0.contains("in use") }
            #expect(inUse == ["\(toolchain) (in use) (default)"])
        }

        try await self.runListTest {
            for toolchain in SwiftlyTests.allToolchains {
                try await inUseTest(toolchain: toolchain, selector: nil)
                try await inUseTest(toolchain: toolchain, selector: toolchain.name)
            }

            let major = SwiftlyTests.oldStable.asStableRelease!.major
            for toolchain in Self.sortedReleaseToolchains.filter({ $0.asStableRelease?.major == major }) {
                try await inUseTest(toolchain: toolchain, selector: "\(major)")
            }

            for toolchain in SwiftlyTests.allToolchains.filter({ $0.asSnapshot?.branch == .main }) {
                try await inUseTest(toolchain: toolchain, selector: "main-snapshot")
            }

            let branch = SwiftlyTests.oldReleaseSnapshot.asSnapshot!.branch
            let releaseSnapshots = SwiftlyTests.allToolchains.filter {
                $0.asSnapshot?.branch == branch
            }
            for toolchain in releaseSnapshots {
                try await inUseTest(toolchain: toolchain, selector: "\(branch.major!).\(branch.minor!)-snapshot")
            }
        }
    }

    /// Tests that `list` properly handles the case where no toolchains have been installed yet.
    @Test(.testHome) func listEmpty() async throws {
        var toolchains = try await self.runList(selector: nil)
        #expect(toolchains == [])

        toolchains = try await self.runList(selector: "5")
        #expect(toolchains == [])

        toolchains = try await self.runList(selector: "main-snapshot")
        #expect(toolchains == [])

        toolchains = try await self.runList(selector: "5.7-snapshot")
        #expect(toolchains == [])
    }
}
