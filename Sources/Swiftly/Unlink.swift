import ArgumentParser
import Foundation
import SwiftlyCore
import SystemPackage

struct Unlink: SwiftlyCommand {
    public static let configuration = CommandConfiguration(
        abstract: "Unlinks swiftly so it no longer manages the active toolchain."
    )

    @Argument(help: ArgumentHelp(
        "Unlinks swiftly, allowing the system default toolchain to be used.",
        discussion: """

        Unlinks swiftly until swiftly is linked again with:

            $ swiftly link
        """
    ))
    var toolchainSelector: String?

    @OptionGroup var root: GlobalOptions

    mutating func run() async throws {
        try await self.run(Swiftly.createDefaultContext())
    }

    mutating func run(_ ctx: SwiftlyCoreContext) async throws {
        let versionUpdateReminder = try await validateSwiftly(ctx)
        defer {
            versionUpdateReminder()
        }

        var pathChanged = false
        let existingProxies = try await symlinkedProxies(ctx)

        for p in existingProxies {
            let proxy = Swiftly.currentPlatform.swiftlyBinDir(ctx) / p

            if try await fs.exists(atPath: proxy) {
                try await fs.remove(atPath: proxy)
                pathChanged = true
            }
        }

        if pathChanged {
            await ctx.message(Messages.unlinkSuccess)

            let shell =
                if let s = ProcessInfo.processInfo.environment["SHELL"] {
                    s
                } else {
                    try await Swiftly.currentPlatform.getShell()
                }

            // Fish and Nushell don't cache executable paths, so the refresh instruction is not applicable.
            if !shell.hasSuffix("nu") && !shell.hasSuffix("fish") {
                let refreshCommand =
                    if shell.hasSuffix("murex") {
                        "murex-update-exe-list"
                    } else {
                        "hash -r"
                    }
                await ctx.message(Messages.refreshShell(refreshCommand))
            }
        }
    }

    func symlinkedProxies(_ ctx: SwiftlyCoreContext) async throws -> [String] {
        if let proxyTo = try? await Swiftly.currentPlatform.findSwiftlyBin(ctx) {
            let swiftlyBinDir = Swiftly.currentPlatform.swiftlyBinDir(ctx)
            let swiftlyBinDirContents = (try? await fs.ls(atPath: swiftlyBinDir)) ?? [String]()
            var proxies = [String]()
            for file in swiftlyBinDirContents {
                let linkTarget = try? await fs.readlink(atPath: swiftlyBinDir / file)
                if linkTarget == proxyTo {
                    proxies.append(file)
                }
            }
            return proxies
        }
        return []
    }
}

extension SwiftlyCommand {
    /// Checks if swiftly is currently linked to manage the active toolchain.
    /// - Parameter ctx: The Swiftly context.
    func validateLinked(_ ctx: SwiftlyCoreContext) async throws {
        if try await !self.isLinked(ctx) {
            await ctx.printError(Messages.currentlyUnlinked)
        }
    }

    private func isLinked(_ ctx: SwiftlyCoreContext) async throws -> Bool {
        guard let proxyTo = try? await Swiftly.currentPlatform.findSwiftlyBin(ctx) else {
            return false
        }

        let swiftlyBinDir = Swiftly.currentPlatform.swiftlyBinDir(ctx)
        guard let swiftlyBinDirContents = try? await fs.ls(atPath: swiftlyBinDir) else {
            return false
        }

        for file in swiftlyBinDirContents {
            // A way to test swiftly locally is to symlink the swiftly executable
            // in the bin dir to one being built from their local swiftly repo.
            if file == "swiftly" {
                continue
            }

            if await (swiftlyBinDir / file).linksTo(proxyTo) {
                return true
            }
        }

        return false
    }
}

extension FilePath {
    fileprivate func linksTo(_ other: FilePath) async -> Bool {
        var path = self
        var jumps = 0
        while jumps < 10 { // More than 10 jumps is probably a symlink loop.
            if path == other {
                return true
            }
            jumps += 1
            do {
                let jumpTarget = try await fs.readlink(atPath: path)
                path = if jumpTarget.isAbsolute {
                    jumpTarget
                } else {
                    path.parent.pushing(jumpTarget).lexicallyNormalized()
                }
            } catch {
                break
            }
        }
        return false
    }
}
