import ArgumentParser
import SwiftlyCore

struct Uninstall: SwiftlyCommand {
    public static let configuration = CommandConfiguration(
        abstract: "Remove an installed toolchain."
    )

    @Argument(help: ArgumentHelp(
        "The toolchain(s) to uninstall.",
        discussion: """

        The toolchain selector provided determines which toolchains to uninstall. Specific \
        toolchains can be uninstalled by using their full names as the selector, for example \
        a full stable release version with patch (a.b.c): 

            $ swiftly uninstall 5.2.1

        Or a full snapshot name with date (a.b-snapshot-YYYY-mm-dd):

            $ swiftly uninstall 5.7-snapshot-2022-06-20

        Less specific selectors can be used to uninstall multiple toolchains at once. For instance, \
        the patch version can be omitted to uninstall all toolchains associated with a given minor version release:

            $ swiftly uninstall 5.6

        Similarly, all snapshot toolchains associated with a given branch can be uninstalled by omitting the date:

            $ swiftly uninstall main-snapshot
            $ swiftly uninstall 5.7-snapshot

        The latest installed stable release can be uninstalled by specifying  'latest':

            $ swiftly uninstall latest

        Finally, all installed toolchains can be uninstalled by specifying 'all':

            $ swiftly uninstall all
        """
    ))
    var toolchain: String

    @OptionGroup var root: GlobalOptions

    mutating func run() async throws {
        try await self.run(Swiftly.createDefaultContext())
    }

    mutating func run(_ ctx: SwiftlyCoreContext) async throws {
        try validateSwiftly(ctx)
        let startingConfig = try Config.load(ctx)

        var toolchains: [ToolchainVersion]
        if self.toolchain == "all" {
            // Sort the uninstalled toolchains such that the in-use toolchain will be uninstalled last.
            // This avoids printing any unnecessary output from using new toolchains while the uninstall is in progress.
            toolchains = startingConfig.listInstalledToolchains(selector: nil).sorted { a, b in
                a != startingConfig.inUse && (b == startingConfig.inUse || a < b)
            }
        } else {
            let selector = try ToolchainSelector(parsing: self.toolchain)
            var installedToolchains = startingConfig.listInstalledToolchains(selector: selector)
            // This is in the unusual case that the inUse toolchain is not listed in the installed toolchains
            if let inUse = startingConfig.inUse, selector.matches(toolchain: inUse) && !startingConfig.installedToolchains.contains(inUse) {
                installedToolchains.append(inUse)
            }
            toolchains = installedToolchains
        }

        // Filter out the xcode toolchain here since it is not uninstallable
        toolchains.removeAll(where: { $0 == .xcodeVersion })

        guard !toolchains.isEmpty else {
            await ctx.print("No toolchains can be uninstalled that match \"\(self.toolchain)\"")
            return
        }

        if !self.root.assumeYes {
            await ctx.print("The following toolchains will be uninstalled:")

            for toolchain in toolchains {
                await ctx.print("  \(toolchain)")
            }

            guard await ctx.promptForConfirmation(defaultBehavior: true) else {
                await ctx.print("Aborting uninstall")
                return
            }
        }

        await ctx.print()

        for toolchain in toolchains {
            var config = try Config.load(ctx)

            // If the in-use toolchain was one of the uninstalled toolchains, use a new toolchain.
            if toolchain == config.inUse {
                let selector: ToolchainSelector
                switch toolchain {
                case let .stable(sr):
                    // If a.b.c was previously in use, switch to the latest a.b toolchain.
                    selector = .stable(major: sr.major, minor: sr.minor, patch: nil)
                case let .snapshot(s):
                    // If a snapshot was previously in use, switch to the latest snapshot associated with that branch.
                    selector = .snapshot(branch: s.branch, date: nil)
                case .xcode:
                    // Xcode will not be in the list of installed toolchains, so this is only here for completeness
                    selector = .xcode
                }

                if let toUse = config.listInstalledToolchains(selector: selector)
                    .filter({ !toolchains.contains($0) })
                    .max()
                    ?? config.listInstalledToolchains(selector: .latest).filter({ !toolchains.contains($0) }).max()
                    ?? config.installedToolchains.filter({ !toolchains.contains($0) }).max()
                {
                    try await Use.execute(ctx, toUse, globalDefault: true, &config)
                } else {
                    // If there are no more toolchains installed, just unuse the currently active toolchain.
                    config.inUse = nil
                    try config.save(ctx)
                }
            }

            try await Self.execute(ctx, toolchain, &config, verbose: self.root.verbose)
        }

        await ctx.print()
        await ctx.print("\(toolchains.count) toolchain(s) successfully uninstalled")
    }

    static func execute(_ ctx: SwiftlyCoreContext, _ toolchain: ToolchainVersion, _ config: inout Config, verbose: Bool) async throws {
        await ctx.print("Uninstalling \(toolchain)...", terminator: "")
        config.installedToolchains.remove(toolchain)
        // This is here to prevent the inUse from referencing a toolchain that is not installed
        if config.inUse == toolchain {
            config.inUse = nil
        }
        try config.save(ctx)

        try await Swiftly.currentPlatform.uninstall(ctx, toolchain, verbose: verbose)
        await ctx.print("done")
    }
}
