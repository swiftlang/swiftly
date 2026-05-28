import Foundation
import OpenAPIRuntime
@testable import SwiftlyCore
import SwiftlyWebsiteAPI
import Testing

@Suite struct SnapshotBranchNotFoundTests {
    typealias SourceBranch = SwiftlyWebsiteAPI.Components.Schemas.SourceBranch

    /// `getSnapshotToolchains` reconstructs the requested branch from the `SourceBranch` so the
    /// `SnapshotBranchNotFoundError` it throws on a 404 carries the branch the caller actually
    /// asked for. This round-trip is the inverse of how the `SourceBranch` is built, and is the
    /// part with real logic, so it is worth pinning even though the 404 check itself is now a
    /// straight inline pattern match in `getSnapshotToolchains`.
    @Test func branchReconstructionRoundTrips() throws {
        #expect(ToolchainVersion.Snapshot.Branch(SourceBranch(.main)) == .main)
        #expect(ToolchainVersion.Snapshot.Branch(SourceBranch("main")) == .main)
        #expect(ToolchainVersion.Snapshot.Branch(SourceBranch("6.0")) == .release(major: 6, minor: 0))
        #expect(ToolchainVersion.Snapshot.Branch(SourceBranch("9.9")) == .release(major: 9, minor: 9))
    }
}
