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

        if !self.root.assumeYes {
            await ctx.print("""
            You are about to uninstall swiftly. 
            This will remove the swiftly binary and all the files in the swiftly home directory. 
            All installed toolchains will not be removed, if you want to remove them, please do so manually with `swiftly uninstall all`.
            This action is irreversible.
            """)

            guard await ctx.promptForConfirmation(defaultBehavior: true) else {
                throw SwiftlyError(message: "swiftly installation has been cancelled")
            }
        }

        try await Self.execute(ctx, verbose: self.root.verbose)
    }

    public static func execute(_ ctx: SwiftlyCoreContext, verbose _: Bool) async throws {
        await ctx.print("Uninstalling swiftly...")

        let userHome = ctx.mockedHomeDir ?? fs.home
        let swiftlyHome = Swiftly.currentPlatform.swiftlyHomeDir(ctx)
        let swiftlyBin = Swiftly.currentPlatform.swiftlyBinDir(ctx)

        let fishSourceLine = """
        # Added by swiftly

        source "\(swiftlyHome / "env.fish")"
        """

        let shSourceLine = """
        # Added by swiftly

        . "\(swiftlyHome / "env.sh")"
        """

        var profilePaths: [FilePath] = [
            userHome / ".zprofile",
            userHome / ".bash_profile",
            userHome / ".bash_login",
            userHome / ".profile",
        ]

        // Handle fish shell config
        if let xdgConfigHome = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"] {
            profilePaths.append(FilePath(xdgConfigHome) / "fish/conf.d/swiftly.fish")
        } else {
            profilePaths.append(userHome / ".config/fish/conf.d/swiftly.fish")
        }

        await ctx.print("Scanning shell profile files to remove swiftly source line...")

        // remove swiftly source line from shell profile files
        for path in profilePaths {
            if try await fs.exists(atPath: path) {
                await ctx.print("Removing swiftly source line from \(path)...")
                let isFishProfile = path.extension == "fish"
                let sourceLine = isFishProfile ? fishSourceLine : shSourceLine
                if case let profileContents = try String(contentsOf: path, encoding: .utf8), profileContents.contains(sourceLine) {
                    let newContents = profileContents.replacingOccurrences(of: sourceLine, with: "")
                    try Data(newContents.utf8).write(to: path, options: [.atomic])
                }
            }
        }

        await ctx.print("Removing swiftly binary from \(swiftlyBin)...")
        try await fs.remove(atPath: swiftlyBin)

        await ctx.print("Removing swiftly home directory from \(swiftlyHome)...")
        try await fs.remove(atPath: swiftlyHome)

        await ctx.print("Swiftly uninstalled successfully.")
    }
}
