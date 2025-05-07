import ArgumentParser
import Foundation
import SwiftlyCore
import SystemPackage

struct SelfUninstall: SwiftlyCommand {
    public static let configuration = CommandConfiguration(
        abstract: "Uninstall swiftly itself.",
    )

    @OptionGroup var root: GlobalOptions

    private enum CodingKeys: String, CodingKey {
        case root
    }

    mutating func run() async throws {
        try await self.run(Swiftly.createDefaultContext())
    }

    mutating func run(_ ctx: SwiftlyCoreContext) async throws {
        let _ = try await validateSwiftly(ctx)
        let swiftlyBin = Swiftly.currentPlatform.swiftlyBinDir(ctx)

        guard try await fs.exists(atPath: swiftlyBin) else {
            throw SwiftlyError(
                message:
                "Self uninstall doesn't work when swiftly has been installed externally. Please uninstall it from the source where you installed it in the first place."
            )
        }

        try await Self.execute(ctx, verbose: self.root.verbose)
    }

    public static func execute(_ ctx: SwiftlyCoreContext, verbose _: Bool) async throws {
        await ctx.print("""
        You are about to uninstall swiftly. 
        This will remove the swiftly binary and all the files in the swiftly home directory. 
        All installed toolchains will not be removed, if you want to remove them, please do so manually with `swiftly uninstall all`.
        This action is irreversible.
        """)

        guard await ctx.promptForConfirmation(defaultBehavior: true) else {
            throw SwiftlyError(message: "swiftly installation has been cancelled")
        }
        await ctx.print("Uninstalling swiftly...")

        let shell = if let mockedShell = ctx.mockedShell {
            mockedShell
        } else {
            if let s = ProcessInfo.processInfo.environment["SHELL"] {
                s
            } else {
                try await Swiftly.currentPlatform.getShell()
            }
        }

        let envFile: FilePath
        let sourceLine: String
        if shell.hasSuffix("fish") {
            envFile = Swiftly.currentPlatform.swiftlyHomeDir(ctx) / "env.fish"
            sourceLine = """

            # Added by swiftly
            source "\(envFile)"
            """
        } else {
            envFile = Swiftly.currentPlatform.swiftlyHomeDir(ctx) / "env.sh"
            sourceLine = """

            # Added by swiftly
            . "\(envFile)"
            """
        }

        let userHome = ctx.mockedHomeDir ?? fs.home

        let profileHome: FilePath
        if shell.hasSuffix("zsh") {
            profileHome = userHome / ".zprofile"
        } else if shell.hasSuffix("bash") {
            if case let p = userHome / ".bash_profile", try await fs.exists(atPath: p) {
                profileHome = p
            } else if case let p = userHome / ".bash_login", try await fs.exists(atPath: p) {
                profileHome = p
            } else {
                profileHome = userHome / ".profile"
            }
        } else if shell.hasSuffix("fish") {
            if let xdgConfigHome = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"], case let xdgConfigURL = FilePath(xdgConfigHome) {
                profileHome = xdgConfigURL / "fish/conf.d/swiftly.fish"
            } else {
                profileHome = userHome / ".config/fish/conf.d/swiftly.fish"
            }
        } else {
            profileHome = userHome / ".profile"
        }

        await ctx.print("Removing swiftly from shell profile at \(profileHome)...")

        if case let profileContents = try String(contentsOf: profileHome, encoding: .utf8), profileContents.contains(sourceLine) {
            let newContents = profileContents.replacingOccurrences(of: sourceLine, with: "")
            try Data(newContents.utf8).write(to: profileHome, options: [.atomic])
        }

        let swiftlyBin = Swiftly.currentPlatform.swiftlyBinDir(ctx)
        let swiftlyHome = Swiftly.currentPlatform.swiftlyHomeDir(ctx)

        await ctx.print("Removing swiftly binary from \(swiftlyBin)...")
        try await fs.remove(atPath: swiftlyBin)

        await ctx.print("Removing swiftly home directory from \(swiftlyHome)...")
        try await fs.remove(atPath: swiftlyHome)

        await ctx.print("Swiftly uninstalled successfully.")
    }
}
