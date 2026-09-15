import Foundation
import SwiftlyCore
import Testing

@Suite struct ToolchainVersionTests {
    @Test func identifierDropsPatchBeforeExplicitPatchSupport() throws {
        #expect(ToolchainVersion(major: 5, minor: 6, patch: 0).identifier == "swift-5.6-RELEASE")
        #expect(ToolchainVersion(major: 6, minor: 3, patch: 0).identifier == "swift-6.3-RELEASE")
        #expect(ToolchainVersion(major: 6, minor: 3, patch: 3).identifier == "swift-6.3.3-RELEASE")
    }

    @Test func identifierKeepsPatchStartingAtFirstReleaseWithExplicitPatch() throws {
        #expect(ToolchainVersion(major: 6, minor: 4, patch: 0).identifier == "swift-6.4.0-RELEASE")
        #expect(ToolchainVersion(major: 6, minor: 4, patch: 1).identifier == "swift-6.4.1-RELEASE")
        #expect(ToolchainVersion(major: 6, minor: 5, patch: 0).identifier == "swift-6.5.0-RELEASE")
        #expect(ToolchainVersion(major: 7, minor: 0, patch: 0).identifier == "swift-7.0.0-RELEASE")
    }
}
