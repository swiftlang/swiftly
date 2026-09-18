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
        
        let nuSourceLine = """
        source "\(swiftlyHome / "env.nu")"
        """

        let murexSourceLine = """
        source "\(swiftlyHome / "env.mx")"
        """

        let shSourceLine = """
        . "\(swiftlyHome / "env.sh")"
        """

        var profilePaths: [FilePath] = [
            userHome / ".zprofile",
            userHome / ".bash_profile",
            userHome / ".bash_login",
            userHome / ".profile",
            userHome / ".murex_profile",
        ]

        // Add fish and nushell config paths
        if let xdgConfigHome = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"] {
            profilePaths.append(FilePath(xdgConfigHome) / "fish/conf.d/swiftly.fish")
            profilePaths.append(FilePath(xdgConfigHome) / "nushell/autoload/swiftly.nu")
        } else {
            profilePaths.append(userHome / ".config/fish/conf.d/swiftly.fish")
            profilePaths.append(userHome / ".config/nushell/autoload/swiftly.nu")
            profilePaths.append(userHome / "Library/Application Support/nushell/autoload/swiftly.nu")
        }

        await ctx.print("Cleaning up shell profile files...")

        // Remove swiftly source lines from shell profiles
        for path in profilePaths where try await fs.exists(atPath: path) {
            if verbose {
                await ctx.print("Checking \(path)...")
            }
            let sourceLine = switch path.lastComponent {
                case "swiftly.fish":   fishSourceLine
                case "swiftly.nu":     nuSourceLine
                case ".murex_profile": murexSourceLine 
                default:               shSourceLine
            }
            let contents = try String(contentsOf: path, encoding: .utf8)
            let linesToRemove = [sourceLine, commentLine]
            var updatedContents = contents
            for line in linesToRemove where contents.contains(line) {
                updatedContents = updatedContents.replacingOccurrences(of: line, with: "")
                if (updatedContents.allSatisfy({ $0.isWhitespace })) {
                    if verbose {
                        await ctx.print("\(path) is now empty, removing it...")
                    }
                    try await fs.remove(atPath: path)
                    break
                } else {
                    try Data(updatedContents.utf8).write(to: path, options: [.atomic])
                    if verbose {
                        await ctx.print("\(path) was updated to remove swiftly line: \(line)")
                    }
                }
            }
        }

        // Remove swiftly symlinks and binary from Swiftly bin directory
        await ctx.print("Checking swiftly bin directory at \(swiftlyBin)...")
        if verbose {
            await ctx.print("--------------------------")
        }
        let swiftlyBinary = swiftlyBin / "swiftly"
        if try await fs.exists(atPath: swiftlyBin) {
            let entries = try await fs.ls(atPath: swiftlyBin)
            for entry in entries {
                let fullPath = swiftlyBin / entry
                guard try await fs.exists(atPath: fullPath) else { continue }
                if try await fs.isSymLink(atPath: fullPath) {
                    let dest = try await fs.readlink(atPath: fullPath)
                    if dest == swiftlyBinary {
                        if verbose {
                            await ctx.print("Removing symlink: \(fullPath) -> \(dest)")
                        }
                        try await fs.remove(atPath: fullPath)
                    }
                }
            }
        }
        // then check if the swiftly binary exists
        if try await fs.exists(atPath: swiftlyBinary) {
            if verbose {
                await ctx.print("Swiftly binary found at \(swiftlyBinary), removing it...")
            }
            try await fs.remove(atPath: swiftlyBin / "swiftly")
        }

        let entries = try await fs.ls(atPath: swiftlyBin)
        if entries.isEmpty {
            if verbose {
                await ctx.print("Swiftly bin directory at \(swiftlyBin) is empty, removing it...")
            }
            try await fs.remove(atPath: swiftlyBin)
        }

        await ctx.print("Checking swiftly home directory at \(swiftlyHome)...")
        if verbose {
            await ctx.print("--------------------------")
        }
        let homeFiles = try? await fs.ls(atPath: swiftlyHome)
        if let homeFiles = homeFiles, homeFiles.contains("config.json") {
            if verbose {
                await ctx.print("Removing swiftly config file at \(swiftlyHome / "config.json")...")
            }
            try await fs.remove(atPath: swiftlyHome / "config.json")
        }
        // look for env.sh, env.fish, env.nu and env.mx
        if let homeFiles = homeFiles, homeFiles.contains("env.sh") {
            if verbose {
                await ctx.print("Removing swiftly env.sh file at \(swiftlyHome / "env.sh")...")
            }
            try await fs.remove(atPath: swiftlyHome / "env.sh")
        }
        if let homeFiles = homeFiles, homeFiles.contains("env.fish") {
            if verbose {
                await ctx.print("Removing swiftly env.fish file at \(swiftlyHome / "env.fish")...")
            }
            try await fs.remove(atPath: swiftlyHome / "env.fish")
        }
        if let homeFiles = homeFiles, homeFiles.contains("env.nu") {
            if verbose {
                await ctx.print("Removing swiftly env.nu file at \(swiftlyHome / "env.nu")...")
            }
            try await fs.remove(atPath: swiftlyHome / "env.nu")
        }
        if let homeFiles = homeFiles, homeFiles.contains("env.mx") {
            if verbose {
                await ctx.print("Removing swiftly env.mx file at \(swiftlyHome / "env.mx")...")
            }
            try await fs.remove(atPath: swiftlyHome / "env.mx")
        }

        // we should also check for share/doc/swiftly/license/LICENSE.txt
        let licensePath = swiftlyHome / "share/doc/swiftly/license/LICENSE.txt"
        if
            try await fs.exists(atPath: licensePath)
        {
            if verbose {
                await ctx.print("Removing swiftly license file at \(licensePath)...")
            }
            try await fs.remove(atPath: licensePath)
        }

        // removes each of share/doc/swiftly/license directories if they are empty
        let licenseDir = swiftlyHome / "share/doc/swiftly/license"
        if try await fs.exists(atPath: licenseDir) {
            let licenseEntries = try await fs.ls(atPath: licenseDir)
            if licenseEntries.isEmpty {
                if verbose {
                    await ctx.print("Swiftly license directory at \(licenseDir) is empty, removing it...")
                }
                try await fs.remove(atPath: licenseDir)
            }
        }

        // if now the swiftly home directory is empty, remove it
        let homeEntries = try await fs.ls(atPath: swiftlyHome)
        await ctx.print("Checking swiftly home directory entries...")
        await ctx.print("still present: \(homeEntries.joined(separator: ", "))")
        if homeEntries.isEmpty {
            if verbose {
                await ctx.print("Swiftly home directory at \(swiftlyHome) is empty, removing it...")
            }
            try await fs.remove(atPath: swiftlyHome)
        }

        await ctx.print("Swiftly is successfully uninstalled.")
    }
}
