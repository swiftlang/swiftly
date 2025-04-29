import Foundation
@testable import Swiftly
@testable import SwiftlyCore
import Testing

@Suite struct ListTests {
    static let homeName = "useTests"

    static let sortedReleaseToolchains: [ToolchainVersion] = [
        .newStable,
        .oldStableNewPatch,
        .oldStable,
    ]

    static let sortedSnapshotToolchains: [ToolchainVersion] = [
        .newMainSnapshot,
        .oldMainSnapshot,
        .newReleaseSnapshot,
        .oldReleaseSnapshot,
    ]

    private static let swiftlyVersion = SwiftlyVersion(major: SwiftlyCore.version.major, minor: 0, patch: 0)

    /// Constructs a mock home directory with the toolchains listed above installed and runs the provided closure within
    /// the context of that home.
    func runListTest(f: () async throws -> Void) async throws {
        try await SwiftlyTests.withTestHome(name: Self.homeName) {
            try await SwiftlyTests.withMockedSwiftlyVersion(latestSwiftlyVersion: Self.swiftlyVersion) {
                for toolchain in Set<ToolchainVersion>.allToolchains() {
                    try await SwiftlyTests.installMockedToolchain(toolchain: toolchain)
                }

                try await SwiftlyTests.runCommand(Use.self, ["use", "latest"])

                try await f()
            }
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
            Set<ToolchainVersion>.allToolchains().first {
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

            var selector = "\(ToolchainVersion.newStable.asStableRelease!.major).\(ToolchainVersion.newStable.asStableRelease!.minor)"
            toolchains = try await self.runList(selector: selector)
            #expect(toolchains == [ToolchainVersion.newStable])

            selector = "\(ToolchainVersion.oldStable.asStableRelease!.major).\(ToolchainVersion.oldStable.asStableRelease!.minor)"
            toolchains = try await self.runList(selector: selector)
            #expect(toolchains == [ToolchainVersion.oldStableNewPatch, ToolchainVersion.oldStable])

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
            #expect(toolchains == [ToolchainVersion.newMainSnapshot, ToolchainVersion.oldMainSnapshot])

            let snapshotBranch = ToolchainVersion.newReleaseSnapshot.asSnapshot!.branch
            toolchains = try await self.runList(selector: "\(snapshotBranch.major!).\(snapshotBranch.minor!)-snapshot")
            #expect(toolchains == [ToolchainVersion.newReleaseSnapshot, ToolchainVersion.oldReleaseSnapshot])

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
            for toolchain in Set<ToolchainVersion>.allToolchains() {
                try await inUseTest(toolchain: toolchain, selector: nil)
                try await inUseTest(toolchain: toolchain, selector: toolchain.name)
            }

            let major = ToolchainVersion.oldStable.asStableRelease!.major
            for toolchain in Self.sortedReleaseToolchains.filter({ $0.asStableRelease?.major == major }) {
                try await inUseTest(toolchain: toolchain, selector: "\(major)")
            }

            for toolchain in Set<ToolchainVersion>.allToolchains().filter({ $0.asSnapshot?.branch == .main }) {
                try await inUseTest(toolchain: toolchain, selector: "main-snapshot")
            }

            let branch = ToolchainVersion.oldReleaseSnapshot.asSnapshot!.branch
            let releaseSnapshots = Set<ToolchainVersion>.allToolchains().filter {
                $0.asSnapshot?.branch == branch
            }
            for toolchain in releaseSnapshots {
                try await inUseTest(toolchain: toolchain, selector: "\(branch.major!).\(branch.minor!)-snapshot")
            }
        }
    }

    /// Tests that `list` properly handles the case where no toolchains have been installed yet.
    @Test(.testHome(Self.homeName)) func listEmpty() async throws {
        try await SwiftlyTests.withMockedSwiftlyVersion(latestSwiftlyVersion: Self.swiftlyVersion) {
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
}
