import ArgumentParser
import SwiftlyCore

struct Update: AsyncParsableCommand {
    @Argument(help: "The toolchain to update.")
    var toolchain: String?

    public mutating func run() async throws {
        guard let oldToolchain = try self.oldToolchain() else {
            if let toolchain = self.toolchain {
                print("No installed toolchain matched \"\(toolchain)\"")
            } else {
                print("No toolchains are currently installed")
            }
            return
        }

        guard let newToolchain = try await self.newToolchain(old: oldToolchain) else {
            print("\(oldToolchain) is already up to date!")
            return
        }

        print("updating \(oldToolchain) -> \(newToolchain)")
        try await Install.execute(version: newToolchain)
        try currentPlatform.uninstall(version: oldToolchain)
        print("successfully updated \(oldToolchain) -> \(newToolchain)")
    }

    private func oldToolchain() throws -> ToolchainVersion? {
        guard let input = self.toolchain else {
            return try currentPlatform.currentToolchain()
        }

        let selector = try ToolchainSelector(parsing: input)
        let toolchains = currentPlatform.listToolchains(selector: selector)

        // When multiple toolchains are matched, update the latest one.
        // This is for situations such as `swiftly update 5.5` when both
        // 5.5.1 and 5.5.2 are installed (5.5.2 will be updated).
        return toolchains.max()
    }

    private func newToolchain(old: ToolchainVersion) async throws -> ToolchainVersion? {
        switch old {
        case let .stable(oldRelease):
            let releases = try await HTTP().getLatestReleases()
            return releases
                .compactMap { try? $0.parse() }
                .filter { release in
                    release.major == oldRelease.major
                        && release.minor == oldRelease.minor
                        && release.patch > oldRelease.patch
                }
                .max()
                .map(ToolchainVersion.stable)
        default:
            // TODO: fetch newer snapshots
            return nil
        }
    }
}
