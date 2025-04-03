import Foundation
import SwiftlyCore
import Testing

@Suite struct ToolchainSelectorTests {
    func runTest(_ expected: ToolchainSelector, _ parses: [String]) throws {
        for string in parses {
            #expect(try ToolchainSelector(parsing: string) == expected)
        }
    }

    @Test func parseLatest() throws {
        try self.runTest(.latest, ["latest"])
    }

    @Test func parseRelease() throws {
        try self.runTest(.stable(major: 5, minor: 7, patch: 3), ["5.7.3"])
        try self.runTest(.stable(major: 5, minor: 7, patch: nil), ["5.7"])
        try self.runTest(.stable(major: 5, minor: nil, patch: nil), ["5"])
    }

    @Test func parseMainSnapshot() throws {
        let parses = [
            "main-snapshot",
            "main-SNAPSHOT",
            "swift-DEVELOPMENT-SNAPSHOT",
        ]
        try runTest(.snapshot(branch: .main, date: nil), parses)
    }

    @Test func parseMainSnapshotWithDate() throws {
        let parses = [
            "main-snapshot-2023-06-05",
            "main-SNAPSHOT-2023-06-05",
            "swift-DEVELOPMENT-SNAPSHOT-2023-06-05",
            "swift-DEVELOPMENT-SNAPSHOT-2023-06-05-a",
            "DEVELOPMENT-SNAPSHOT-2023-06-05-a",
        ]
        try runTest(.snapshot(branch: .main, date: "2023-06-05"), parses)
    }

    @Test func parseReleaseSnapshot() throws {
        let parses = [
            "5.7-snapshot",
            "5.7-SNAPSHOT",
            "5.7-DEVELOPMENT-SNAPSHOT",
            "swift-5.7-snapshot",
            "swift-5.7-SNAPSHOT",
            "swift-5.7-DEVELOPMENT-SNAPSHOT",
        ]
        try runTest(.snapshot(branch: .release(major: 5, minor: 7), date: nil), parses)
    }

    @Test func parseReleaseSnapshotWithDate() throws {
        let parses = [
            "5.7-snapshot-2023-06-05",
            "5.7-SNAPSHOT-2023-06-05",
            "5.7-DEVELOPMENT-SNAPSHOT-2023-06-05",
            "5.7-DEVELOPMENT-SNAPSHOT-2023-06-05-a",
            "swift-5.7-snapshot-2023-06-05",
            "swift-5.7-SNAPSHOT-2023-06-05",
            "swift-5.7-DEVELOPMENT-SNAPSHOT-2023-06-05",
            "swift-5.7-DEVELOPMENT-SNAPSHOT-2023-06-05-a",
        ]
        try runTest(.snapshot(branch: .release(major: 5, minor: 7), date: "2023-06-05"), parses)
    }
}
