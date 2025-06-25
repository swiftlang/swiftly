import Foundation
@testable import Swiftly
@testable import SwiftlyCore
import Testing

@Suite struct OutputSchemaTests {
    // MARK: - Test Data Setup

    static let testStableToolchain = ToolchainVersion.stable(.init(major: 5, minor: 8, patch: 1))
    static let testMainSnapshot = ToolchainVersion.snapshot(.init(branch: .main, date: "2023-07-15"))
    static let testReleaseSnapshot = ToolchainVersion.snapshot(.init(branch: .release(major: 5, minor: 9), date: "2023-07-10"))

    static let testStableVersionInfo = ToolchainVersion.stable(.init(major: 5, minor: 8, patch: 1))

    static let testMainSnapshotVersionInfo = ToolchainVersion.snapshot(.init(branch: .main, date: "2023-07-15"))

    static let testReleaseSnapshotVersionInfo = ToolchainVersion.snapshot(.init(branch: .release(major: 5, minor: 9), date: "2023-07-10"))

    // MARK: - ToolchainVersion Tests

    @Test func toolchainVersionName() async throws {
        #expect(Self.testStableVersionInfo.name == "5.8.1")
        #expect(Self.testMainSnapshotVersionInfo.name == "main-snapshot-2023-07-15")
        #expect(Self.testReleaseSnapshotVersionInfo.name == "5.9-snapshot-2023-07-10")
    }

    // MARK: - AvailableToolchainInfo Tests

    @Test func availableToolchainInfoDescription() async throws {
        let basicToolchain = AvailableToolchainInfo(
            version: Self.testStableVersionInfo,
            inUse: false,
            isDefault: false,
            installed: false
        )
        #expect(basicToolchain.description == "Swift 5.8.1")

        let installedToolchain = AvailableToolchainInfo(
            version: Self.testStableVersionInfo,
            inUse: false,
            isDefault: false,
            installed: true
        )
        #expect(installedToolchain.description == "Swift 5.8.1 (installed)")

        let inUseToolchain = AvailableToolchainInfo(
            version: Self.testStableVersionInfo,
            inUse: true,
            isDefault: false,
            installed: true
        )
        #expect(inUseToolchain.description == "Swift 5.8.1 (installed) (in use)")

        let defaultToolchain = AvailableToolchainInfo(
            version: Self.testStableVersionInfo,
            inUse: true,
            isDefault: true,
            installed: true
        )
        #expect(defaultToolchain.description == "Swift 5.8.1 (installed) (in use) (default)")

        let defaultOnlyToolchain = AvailableToolchainInfo(
            version: Self.testStableVersionInfo,
            inUse: false,
            isDefault: true,
            installed: false
        )
        #expect(defaultOnlyToolchain.description == "Swift 5.8.1 (default)")
    }

    @Test func availableToolchainsListInfoDescriptionNoSelector() async throws {
        let toolchains = [
            AvailableToolchainInfo(
                version: Self.testStableVersionInfo,
                inUse: true,
                isDefault: true,
                installed: true
            ),
            AvailableToolchainInfo(
                version: Self.testMainSnapshotVersionInfo,
                inUse: false,
                isDefault: false,
                installed: false
            ),
        ]

        let listInfo = AvailableToolchainsListInfo(toolchains: toolchains)
        let description = listInfo.description

        #expect(description.contains("Available release toolchains"))
        #expect(description.contains("----------------------------"))
        #expect(description.contains("Swift 5.8.1 (installed) (in use) (default)"))
        #expect(description.contains("main-snapshot-2023-07-15"))
    }

    @Test func availableToolchainsListInfoDescriptionWithStableSelector() async throws {
        let toolchains = [
            AvailableToolchainInfo(
                version: Self.testStableVersionInfo,
                inUse: true,
                isDefault: true,
                installed: true
            ),
        ]

        let selector = ToolchainSelector.stable(major: 5, minor: 8, patch: nil)
        let listInfo = AvailableToolchainsListInfo(toolchains: toolchains, selector: selector)
        let description = listInfo.description

        #expect(description.contains("Available Swift 5.8 release toolchains"))
        #expect(description.contains("Swift 5.8.1 (installed) (in use) (default)"))
    }

    @Test func availableToolchainsListInfoDescriptionWithMajorOnlySelector() async throws {
        let majorOnlySelector = ToolchainSelector.stable(major: 5, minor: nil, patch: nil)
        let majorOnlyListInfo = AvailableToolchainsListInfo(
            toolchains: [AvailableToolchainInfo(
                version: Self.testStableVersionInfo,
                inUse: false,
                isDefault: false,
                installed: true
            )],
            selector: majorOnlySelector
        )
        #expect(majorOnlyListInfo.description.contains("Available Swift 5 release toolchains"))
        #expect(majorOnlyListInfo.description.contains("Swift 5.8.1 (installed)"))
    }

    @Test func availableToolchainsListInfoDescriptionWithMainSnapshotSelector() async throws {
        let mainSnapshotSelector = ToolchainSelector.snapshot(branch: .main, date: nil)
        let mainSnapshotListInfo = AvailableToolchainsListInfo(
            toolchains: [AvailableToolchainInfo(
                version: Self.testMainSnapshotVersionInfo,
                inUse: false,
                isDefault: false,
                installed: false
            )],
            selector: mainSnapshotSelector
        )
        #expect(mainSnapshotListInfo.description.contains("Available main development snapshot toolchains"))
        #expect(mainSnapshotListInfo.description.contains("main-snapshot-2023-07-15"))
    }

    @Test func availableToolchainsListInfoDescriptionWithReleaseSnapshotSelector() async throws {
        let releaseSnapshotSelector = ToolchainSelector.snapshot(branch: .release(major: 5, minor: 9), date: nil)
        let releaseSnapshotListInfo = AvailableToolchainsListInfo(
            toolchains: [AvailableToolchainInfo(
                version: Self.testReleaseSnapshotVersionInfo,
                inUse: false,
                isDefault: false,
                installed: true
            )],
            selector: releaseSnapshotSelector
        )
        #expect(releaseSnapshotListInfo.description.contains("Available 5.9 development snapshot toolchains"))
        #expect(releaseSnapshotListInfo.description.contains("5.9-snapshot-2023-07-10 (installed)"))
    }

    @Test func availableToolchainsListInfoDescriptionWithSpecificVersionSelector() async throws {
        let specificSelector = ToolchainSelector.stable(major: 5, minor: 8, patch: 1)
        let specificListInfo = AvailableToolchainsListInfo(
            toolchains: [AvailableToolchainInfo(
                version: Self.testStableVersionInfo,
                inUse: false,
                isDefault: false,
                installed: false
            )],
            selector: specificSelector
        )
        #expect(specificListInfo.description.contains("Available matching toolchains"))
        #expect(specificListInfo.description.contains("Swift 5.8.1"))
    }

    @Test func availableToolchainsListInfoEmptyToolchains() async throws {
        let listInfo = AvailableToolchainsListInfo(toolchains: [])
        let description = listInfo.description

        #expect(description.contains("Available release toolchains"))
        #expect(description.contains("----------------------------"))
        // Should not contain any toolchain entries
        #expect(!description.contains("Swift 5.8.1"))
        #expect(!description.contains("snapshot"))
    }
}
