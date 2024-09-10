import Foundation
@testable import Swiftly
@testable import SwiftlyCore
import XCTest

final class ListTests: SwiftlyTests {
    static let homeName = "useTests"

    static let sortedReleaseToolchains: [ToolchainVersion] = [
        ListTests.newStable,
        ListTests.oldStableNewPatch,
        ListTests.oldStable,
    ]

    static let sortedSnapshotToolchains: [ToolchainVersion] = [
        ListTests.newMainSnapshot,
        ListTests.oldMainSnapshot,
        ListTests.newReleaseSnapshot,
        ListTests.oldReleaseSnapshot,
    ]

    /// Constructs a mock home directory with the toolchains listed above installed and runs the provided closure within
    /// the context of that home.
    func runListTest(f: () async throws -> Void) async throws {
        try await self.withTestHome(name: Self.homeName) {
            for toolchain in Self.allToolchains {
                try await self.installMockedToolchain(toolchain: toolchain)
            }

            var use = try self.parseCommand(Use.self, ["use", "latest"])
            try await use.run()

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

        var list = try self.parseCommand(List.self, args)
        let output = try await list.runWithMockedIO()

        let parsedToolchains = output.compactMap { outputLine in
            Self.allToolchains.first {
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
    func testList() async throws {
        try await self.runListTest {
            let toolchains = try await self.runList(selector: nil)
            XCTAssertEqual(toolchains, Self.sortedReleaseToolchains + Self.sortedSnapshotToolchains)
        }
    }

    /// Tests that running `swiftly list` with a release version selector filters out unmatching toolchains and prints
    /// in descending order.
    func testListReleaseToolchains() async throws {
        try await self.runListTest {
            var toolchains = try await self.runList(selector: "5")
            XCTAssertEqual(toolchains, Self.sortedReleaseToolchains)

            var selector = "\(Self.newStable.asStableRelease!.major).\(Self.newStable.asStableRelease!.minor)"
            toolchains = try await self.runList(selector: selector)
            XCTAssertEqual(toolchains, [Self.newStable])

            selector = "\(Self.oldStable.asStableRelease!.major).\(Self.oldStable.asStableRelease!.minor)"
            toolchains = try await self.runList(selector: selector)
            XCTAssertEqual(toolchains, [Self.oldStableNewPatch, Self.oldStable])

            for toolchain in Self.sortedReleaseToolchains {
                toolchains = try await self.runList(selector: toolchain.name)
                XCTAssertEqual(toolchains, [toolchain])
            }

            toolchains = try await self.runList(selector: "4")
            XCTAssertEqual(toolchains, [])
        }
    }

    /// Tests that running `swiftly list` with a snapshot selector filters out unmatching toolchains and prints
    /// in descending order.
    func testListSnapshotToolchains() async throws {
        try await self.runListTest {
            var toolchains = try await self.runList(selector: "main-snapshot")
            XCTAssertEqual(toolchains, [Self.newMainSnapshot, Self.oldMainSnapshot])

            let snapshotBranch = Self.newReleaseSnapshot.asSnapshot!.branch
            toolchains = try await self.runList(selector: "\(snapshotBranch.major!).\(snapshotBranch.minor!)-snapshot")
            XCTAssertEqual(toolchains, [Self.newReleaseSnapshot, Self.oldReleaseSnapshot])

            for toolchain in Self.sortedSnapshotToolchains {
                toolchains = try await self.runList(selector: toolchain.name)
                XCTAssertEqual(toolchains, [toolchain])
            }

            toolchains = try await self.runList(selector: "1.2-snapshot")
            XCTAssertEqual(toolchains, [])
        }
    }

    /// Tests that the "(in use)" marker is correctly printed when listing installed toolchains.
    func testListInUse() async throws {
        func inUseTest(toolchain: ToolchainVersion, selector: String?) async throws {
            var use = try self.parseCommand(Use.self, ["use", toolchain.name])
            try await use.run()

            var listArgs = ["list"]
            if let selector {
                listArgs.append(selector)
            }
            var list = try self.parseCommand(List.self, listArgs)
            let output = try await list.runWithMockedIO()

            let inUse = output.filter { $0.contains("in use") }
            XCTAssertEqual(inUse, ["\(toolchain) (in use) (default)"])
        }

        try await self.runListTest {
            for toolchain in Self.allToolchains {
                try await inUseTest(toolchain: toolchain, selector: nil)
                try await inUseTest(toolchain: toolchain, selector: toolchain.name)
            }

            let major = Self.oldStable.asStableRelease!.major
            for toolchain in Self.sortedReleaseToolchains.filter({ $0.asStableRelease?.major == major }) {
                try await inUseTest(toolchain: toolchain, selector: "\(major)")
            }

            for toolchain in Self.allToolchains.filter({ $0.asSnapshot?.branch == .main }) {
                try await inUseTest(toolchain: toolchain, selector: "main-snapshot")
            }

            let branch = Self.oldReleaseSnapshot.asSnapshot!.branch
            let releaseSnapshots = Self.allToolchains.filter {
                $0.asSnapshot?.branch == branch
            }
            for toolchain in releaseSnapshots {
                try await inUseTest(toolchain: toolchain, selector: "\(branch.major!).\(branch.minor!)-snapshot")
            }
        }
    }

    /// Tests that `list` properly handles the case where no toolchains been installed yet.
    func testListEmpty() async throws {
        try await self.withTestHome {
            var toolchains = try await self.runList(selector: nil)
            XCTAssertEqual(toolchains, [])

            toolchains = try await self.runList(selector: "5")
            XCTAssertEqual(toolchains, [])

            toolchains = try await self.runList(selector: "main-snapshot")
            XCTAssertEqual(toolchains, [])

            toolchains = try await self.runList(selector: "5.7-snapshot")
            XCTAssertEqual(toolchains, [])
        }
    }
}
