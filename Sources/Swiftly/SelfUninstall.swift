// SelfUninstall.swift

import ArgumentParser
import Foundation
import SwiftlyCore
import SystemPackage

struct SelfUninstall: SwiftlyCommand {
    static let configuration = CommandConfiguration(
        abstract: "Uninstall swiftly itself."
    )

    @OptionGroup var root: GlobalOptions

    private enum CodingKeys: String, CodingKey {
        case root
    }

    mutating func run() async throws {
        try await self.run(Swiftly.createDefaultContext())
    }

    mutating func run(_ ctx: SwiftlyCoreContext) async throws {
        _ = try await validateSwiftly(ctx)
        let swiftlyBin = Swiftly.currentPlatform.swiftlyBinDir(ctx)

        guard try await fs.exists(atPath: swiftlyBin) else {
            throw SwiftlyError(
                message: "Self uninstall doesn't work when swiftly has been installed externally. Please uninstall it from the source where you installed it in the first place."
            )
        }

        if !self.root.assumeYes {
            await ctx.print("""
            You are about to uninstall swiftly.
            This will remove the swiftly binary and all files in the swiftly home directory.
            Installed toolchains will not be removed. To remove them, run `swiftly uninstall all`.
            This action is irreversible.
            """)
            guard await ctx.promptForConfirmation(defaultBehavior: true) else {
                throw SwiftlyError(message: "swiftly installation has been cancelled")
            }
        }

        try await Self.execute(ctx, verbose: self.root.verbose)
    }

    static func execute(_ ctx: SwiftlyCoreContext, verbose: Bool) async throws {
        await ctx.print("Uninstalling swiftly...")

        let userHome = ctx.mockedHomeDir ?? fs.home
        let swiftlyHome = Swiftly.currentPlatform.swiftlyHomeDir(ctx)
        let swiftlyBin = Swiftly.currentPlatform.swiftlyBinDir(ctx)

        let commentLine = """
        # Added by swiftly
        """
        let fishSourceLine = """
        source "\(swiftlyHome / "env.fish")"
        """

        let shSourceLine = """
        . "\(swiftlyHome / "env.sh")"
        """

        var profilePaths: [FilePath] = [
            userHome / ".zprofile",
            userHome / ".bash_profile",
            userHome / ".bash_login",
            userHome / ".profile",
        ]

        // Add fish shell config path
        if let xdgConfigHome = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"] {
            profilePaths.append(FilePath(xdgConfigHome) / "fish/conf.d/swiftly.fish")
        } else {
            profilePaths.append(userHome / ".config/fish/conf.d/swiftly.fish")
        }

        await ctx.print("Cleaning up shell profile files...")

        // Remove swiftly source lines from shell profiles
        for path in profilePaths where try await fs.exists(atPath: path) {
            if verbose {
                await ctx.print("Checking \(path)...")
            }
            let isFish = path.extension == "fish"
            let sourceLine = isFish ? fishSourceLine : shSourceLine
            let contents = try String(contentsOf: path, encoding: .utf8)
            let linesToRemove = [sourceLine, commentLine]
            var updatedContents = contents
            for line in linesToRemove where contents.contains(line) {
                updatedContents = updatedContents.replacingOccurrences(of: line, with: "")
                try Data(updatedContents.utf8).write(to: path, options: [.atomic])
                if verbose {
                    await ctx.print("\(path) was updated to remove swiftly line: \(line)")
                }
            }
        }

        await ctx.print("Removing swiftly binary at \(swiftlyBin)...")
        try await fs.remove(atPath: swiftlyBin)

        await ctx.print("Removing swiftly home directory at \(swiftlyHome)...")
        try await fs.remove(atPath: swiftlyHome)

        await ctx.print("Swiftly uninstalled successfully.")
    }
}
