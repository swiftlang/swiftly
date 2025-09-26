import ArgumentParser
import SwiftlyCore

struct Uninstall: SwiftlyCommand {
    public static let configuration = CommandConfiguration(
        abstract: "Remove an installed toolchain."
    )

    private enum UninstallConstants {
        static let allSelector = "all"
    }

    private struct UninstallCancelledError: Error {}

    private struct ToolchainSelectionResult {
        let validToolchains: Set<ToolchainVersion>
        let selectorToToolchains: [String: [ToolchainVersion]]
        let invalidSelectors: [String]
        let noMatchSelectors: [String]
    }

    @Argument(help: ArgumentHelp(
        "The toolchain(s) to uninstall.",
        discussion: """

        The list of toolchain selectors determines which toolchains to uninstall. Specific \
        toolchains can be uninstalled by using their full names as the selector, for example \
        a full stable release version with patch (a.b.c):

            $ swiftly uninstall 5.2.1

        Or a full snapshot name with date (a.b-snapshot-YYYY-mm-dd):

            $ swiftly uninstall 5.7-snapshot-2022-06-20

        Multiple toolchain selectors can uninstall multiple toolchains at once:

            $ swiftly uninstall 5.2.1 6.0.1

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
    var toolchains: [String]

    @OptionGroup var root: GlobalOptions

    mutating func run() async throws {
        try await self.run(Swiftly.createDefaultContext())
    }

    mutating func run(_ ctx: SwiftlyCoreContext) async throws {
        let versionUpdateReminder = try await validateSwiftly(ctx)
        defer {
            versionUpdateReminder()
        }

        let startingConfig = try await Config.load(ctx)
        let selectionResult = try await parseAndValidateToolchainSelectors(startingConfig)
        let confirmedToolchains = try await handleErrorsAndGetConfirmation(ctx, selectionResult)

        try await executeUninstalls(ctx, confirmedToolchains, startingConfig)
    }

    private func parseAndValidateToolchainSelectors(_ config: Config) async throws -> ToolchainSelectionResult {
        var allToolchains: Set<ToolchainVersion> = Set()
        var selectorToToolchains: [String: [ToolchainVersion]] = [:]
        var invalidSelectors: [String] = []
        var noMatchSelectors: [String] = []

        for toolchainSelector in self.toolchains {
            if toolchainSelector == UninstallConstants.allSelector {
                let allInstalledToolchains = self.processAllSelector(config)
                allToolchains.formUnion(allInstalledToolchains)
                selectorToToolchains[toolchainSelector] = allInstalledToolchains
            } else {
                do {
                    let installedToolchains = try processIndividualSelector(toolchainSelector, config)

                    if installedToolchains.isEmpty {
                        noMatchSelectors.append(toolchainSelector)
                    } else {
                        allToolchains.formUnion(installedToolchains)
                        selectorToToolchains[toolchainSelector] = installedToolchains
                    }
                } catch {
                    invalidSelectors.append(toolchainSelector)
                }
            }
        }

        return ToolchainSelectionResult(
            validToolchains: allToolchains,
            selectorToToolchains: selectorToToolchains,
            invalidSelectors: invalidSelectors,
            noMatchSelectors: noMatchSelectors
        )
    }

    private func processAllSelector(_ config: Config) -> [ToolchainVersion] {
        config.listInstalledToolchains(selector: nil).sorted { a, b in
            a != config.inUse && (b == config.inUse || a < b)
        }
    }

    private func processIndividualSelector(_ selector: String, _ config: Config) throws -> [ToolchainVersion] {
        let toolchainSelector = try ToolchainSelector(parsing: selector)
        var installedToolchains = config.listInstalledToolchains(selector: toolchainSelector)

        // This handles the unusual case that the inUse toolchain is not listed in the installed toolchains
        if let inUse = config.inUse, toolchainSelector.matches(toolchain: inUse) && !config.installedToolchains.contains(inUse) {
            installedToolchains.append(inUse)
        }

        return installedToolchains
    }

    private func handleErrorsAndGetConfirmation(
        _ ctx: SwiftlyCoreContext,
        _ selectionResult: ToolchainSelectionResult
    ) async throws -> [ToolchainVersion] {
        if self.hasErrors(selectionResult) {
            try await self.handleSelectionErrors(ctx, selectionResult)
        }

        let toolchains = self.prepareToolchainsForUninstall(selectionResult)

        guard !toolchains.isEmpty else {
            if self.toolchains.count == 1 {
                await ctx.message("No toolchains can be uninstalled that match \"\(self.toolchains[0])\"")
            } else {
                await ctx.message("No toolchains can be uninstalled that match the provided selectors")
            }
            throw UninstallCancelledError()
        }

        if !self.root.assumeYes {
            try await self.confirmUninstallation(ctx, toolchains, selectionResult.selectorToToolchains)
        }

        return toolchains
    }

    private func hasErrors(_ result: ToolchainSelectionResult) -> Bool {
        !result.invalidSelectors.isEmpty || !result.noMatchSelectors.isEmpty
    }

    private func handleSelectionErrors(_ ctx: SwiftlyCoreContext, _ result: ToolchainSelectionResult) async throws {
        var errorMessages: [String] = []

        if !result.invalidSelectors.isEmpty {
            errorMessages.append("Invalid toolchain selectors: \(result.invalidSelectors.joined(separator: ", "))")
        }

        if !result.noMatchSelectors.isEmpty {
            errorMessages.append("No toolchains match these selectors: \(result.noMatchSelectors.joined(separator: ", "))")
        }

        for message in errorMessages {
            await ctx.message(message)
        }

        // If we have some valid selections, ask user if they want to proceed
        if !result.validToolchains.isEmpty {
            await ctx.message("\nFound \(result.validToolchains.count) toolchain(s) from valid selectors. Continue with uninstalling these?")
            guard await ctx.promptForConfirmation(defaultBehavior: false) else {
                await ctx.message("Aborting uninstall")
                throw UninstallCancelledError()
            }
        } else {
            // No valid toolchains found at all
            await ctx.message("No valid toolchains found to uninstall.")
            throw UninstallCancelledError()
        }
    }

    private func prepareToolchainsForUninstall(_ selectionResult: ToolchainSelectionResult) -> [ToolchainVersion] {
        // Convert Set back to Array - sorting will be done in execution phase with proper config access
        var toolchains = Array(selectionResult.validToolchains)

        // Filter out the xcode toolchain here since it is not uninstallable
        toolchains.removeAll(where: { $0 == .xcodeVersion })

        return toolchains
    }

    private func confirmUninstallation(
        _ ctx: SwiftlyCoreContext,
        _ toolchains: [ToolchainVersion],
        _ _: [String: [ToolchainVersion]]
    ) async throws {
        await self.displayToolchainConfirmation(ctx, toolchains)

        guard await ctx.promptForConfirmation(defaultBehavior: true) else {
            await ctx.message("Aborting uninstall")
            throw UninstallCancelledError()
        }
    }

    private func displayToolchainConfirmation(_ ctx: SwiftlyCoreContext, _ toolchains: [ToolchainVersion]) async {
        await ctx.message("The following toolchains will be uninstalled:")
        for toolchain in toolchains.sorted() {
            await ctx.message("  \(toolchain)")
        }
    }

    private func executeUninstalls(
        _ ctx: SwiftlyCoreContext,
        _ toolchains: [ToolchainVersion],
        _ startingConfig: Config
    ) async throws {
        await ctx.message()

        // Apply proper sorting with access to config
        let sortedToolchains = self.applySortingStrategy(toolchains, config: startingConfig)

        for (index, toolchain) in sortedToolchains.enumerated() {
            await self.displayProgress(ctx, index: index, total: sortedToolchains.count, toolchain: toolchain)

            var config = try await Config.load(ctx)

            if toolchain == config.inUse {
                try await self.handleInUseToolchainReplacement(ctx, toolchain, sortedToolchains, &config)
            }

            try await Self.execute(ctx, toolchain, &config, verbose: self.root.verbose)
        }

        await self.displayCompletionMessage(ctx, sortedToolchains.count)
    }

    private func applySortingStrategy(_ toolchains: [ToolchainVersion], config: Config) -> [ToolchainVersion] {
        toolchains.sorted { a, b in
            a != config.inUse && (b == config.inUse || a < b)
        }
    }

    private func handleInUseToolchainReplacement(
        _ ctx: SwiftlyCoreContext,
        _ toolchain: ToolchainVersion,
        _ allUninstallTargets: [ToolchainVersion],
        _ config: inout Config
    ) async throws {
        let replacementSelector = self.createReplacementSelector(for: toolchain)

        if let replacement = self.findSuitableReplacement(config, replacementSelector, excluding: allUninstallTargets) {
            let pathChanged = try await Use.execute(ctx, replacement, globalDefault: true, verbose: self.root.verbose, &config)
            if pathChanged {
                try await Self.handlePathChange(ctx)
            }
        } else {
            config.inUse = nil
            try config.save(ctx)
        }
    }

    private func createReplacementSelector(for toolchain: ToolchainVersion) -> ToolchainSelector {
        switch toolchain {
        case let .stable(sr):
            // If a.b.c was previously in use, switch to the latest a.b toolchain.
            return .stable(major: sr.major, minor: sr.minor, patch: nil)
        case let .snapshot(s):
            // If a snapshot was previously in use, switch to the latest snapshot associated with that branch.
            return .snapshot(branch: s.branch, date: nil)
        case .xcode:
            // Xcode will not be in the list of installed toolchains, so this is only here for completeness
            return .xcode
        }
    }

    private func findSuitableReplacement(
        _ config: Config,
        _ selector: ToolchainSelector,
        excluding: [ToolchainVersion]
    ) -> ToolchainVersion? {
        // Try the specific selector first
        if let replacement = config.listInstalledToolchains(selector: selector)
            .filter({ !excluding.contains($0) })
            .max()
        {
            return replacement
        }

        // Try latest stable as fallback, but only if there are stable toolchains
        let stableToolchains = config.installedToolchains.filter { $0.isStableRelease() && !excluding.contains($0) }
        if !stableToolchains.isEmpty {
            return stableToolchains.max()
        }

        // Finally, try any remaining toolchain
        return config.installedToolchains.filter { !excluding.contains($0) }.max()
    }

    private func displayProgress(_ ctx: SwiftlyCoreContext, index: Int, total: Int, toolchain: ToolchainVersion) async {
        if total > 1 {
            await ctx.message("[\(index + 1)/\(total)] Processing \(toolchain)")
        }
    }

    private func displayCompletionMessage(_ ctx: SwiftlyCoreContext, _ toolchainCount: Int) async {
        await ctx.message()
        if self.toolchains.count == 1 {
            await ctx.message("\(toolchainCount) toolchain(s) successfully uninstalled")
        } else {
            await ctx.message("Successfully uninstalled \(toolchainCount) toolchain(s) from \(self.toolchains.count) selector(s)")
        }
    }

    static func execute(
        _ ctx: SwiftlyCoreContext, _ toolchain: ToolchainVersion, _ config: inout Config,
        verbose: Bool
    ) async throws {
        await ctx.message("Uninstalling \(toolchain)... ", terminator: "")
        let lockFile = Swiftly.currentPlatform.swiftlyHomeDir(ctx) / "swiftly.lock"
        if verbose {
            await ctx.message("Attempting to acquire installation lock at \(lockFile) ...")
        }

        config = try await withLock(lockFile) {
            var config = try await Config.load(ctx)
            config.installedToolchains.remove(toolchain)
            // This is here to prevent the inUse from referencing a toolchain that is not installed
            if config.inUse == toolchain {
                config.inUse = nil
            }
            try config.save(ctx)

            try await Swiftly.currentPlatform.uninstall(ctx, toolchain, verbose: verbose)
            return config
        }
        await ctx.message("done")
    }
}
