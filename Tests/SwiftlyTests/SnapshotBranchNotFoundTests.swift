import Foundation
import OpenAPIRuntime
@testable import SwiftlyCore
import SwiftlyWebsiteAPI
import Testing

@Suite struct SnapshotBranchNotFoundTests {
    typealias Output = SwiftlyWebsiteAPI.Operations.ListDevToolchains.Output
    typealias SourceBranch = SwiftlyWebsiteAPI.Components.Schemas.SourceBranch

    /// A 404 from the dev-toolchains endpoint, which swift.org returns for a branch that doesn't
    /// exist, must be surfaced as a typed `SnapshotBranchNotFoundError` rather than the raw,
    /// low-level HTTP error. This is the error the `install`, `list-available`, and `update`
    /// commands catch to present an actionable message.
    @Test func notFoundResponseMapsToTypedErrorForReleaseBranch() throws {
        let response: Output = .undocumented(statusCode: 404, .init())
        let sourceBranch = SourceBranch("9.9")

        #expect(throws: SwiftlyHTTPClient.SnapshotBranchNotFoundError.self) {
            _ = try HTTPRequestExecutorImpl.devToolchains(from: response, branch: sourceBranch)
        }

        do {
            _ = try HTTPRequestExecutorImpl.devToolchains(from: response, branch: sourceBranch)
            Issue.record("expected a SnapshotBranchNotFoundError to be thrown")
        } catch let error as SwiftlyHTTPClient.SnapshotBranchNotFoundError {
            #expect(error.branch == .release(major: 9, minor: 9))
        }
    }

    @Test func notFoundResponseMapsToTypedErrorForMainBranch() throws {
        let response: Output = .undocumented(statusCode: 404, .init())
        let sourceBranch = SourceBranch(.main)

        do {
            _ = try HTTPRequestExecutorImpl.devToolchains(from: response, branch: sourceBranch)
            Issue.record("expected a SnapshotBranchNotFoundError to be thrown")
        } catch let error as SwiftlyHTTPClient.SnapshotBranchNotFoundError {
            #expect(error.branch == .main)
        }
    }

    /// A successful (200) response must still return the parsed toolchains untouched.
    @Test func okResponseReturnsToolchains() throws {
        let response: Output = .ok(.init(body: .json(.init())))
        let result = try HTTPRequestExecutorImpl.devToolchains(from: response, branch: SourceBranch(.main))
        #expect(result.universal == nil)
        #expect(result.aarch64 == nil)
        #expect(result.x8664 == nil)
    }

    /// Non-404 undocumented responses (for example a 5xx server error) should not be misreported
    /// as a missing branch; they must propagate as the original error from `.ok`.
    @Test func serverErrorIsNotReportedAsMissingBranch() throws {
        let response: Output = .undocumented(statusCode: 500, .init())

        #expect(throws: (any Error).self) {
            _ = try HTTPRequestExecutorImpl.devToolchains(from: response, branch: SourceBranch(.main))
        }

        do {
            _ = try HTTPRequestExecutorImpl.devToolchains(from: response, branch: SourceBranch(.main))
            Issue.record("expected an error to be thrown for a 500 response")
        } catch is SwiftlyHTTPClient.SnapshotBranchNotFoundError {
            Issue.record("a 500 response must not be reported as a missing snapshot branch")
        } catch {
            // Expected: the generic unexpected-response error from the OpenAPI runtime.
        }
    }

    /// The branch reconstruction is the inverse of how `SwiftlyHTTPClient.getSnapshotToolchains`
    /// builds the `SourceBranch`, so the error carries the branch the caller actually requested.
    @Test func branchReconstructionRoundTrips() throws {
        #expect(ToolchainVersion.Snapshot.Branch(SourceBranch(.main)) == .main)
        #expect(ToolchainVersion.Snapshot.Branch(SourceBranch("main")) == .main)
        #expect(ToolchainVersion.Snapshot.Branch(SourceBranch("6.0")) == .release(major: 6, minor: 0))
        #expect(ToolchainVersion.Snapshot.Branch(SourceBranch("9.9")) == .release(major: 9, minor: 9))
    }
}
