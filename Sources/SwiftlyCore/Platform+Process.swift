import Foundation
import Subprocess
#if os(macOS)
import System
#endif

import SystemPackage
#if os(Windows)
import TSCBasic
#endif

extension Subprocess.Executable {
#if os(macOS)
    public static func path(_ filePath: SystemPackage.FilePath) -> Self {
        .path(System.FilePath(filePath.string))
    }
#endif
}

extension Platform {
#if os(macOS) || os(Linux)
    public func proxyEnvironment(_ ctx: SwiftlyCoreContext, env: Environment, toolchain: ToolchainVersion) async throws -> Environment {
        var environment = env

        let tcPath = try await self.findToolchainLocation(ctx, toolchain) / "usr/bin"
        guard try await fs.exists(atPath: tcPath) else {
            throw SwiftlyError(
                message:
                "Toolchain \(toolchain) could not be located in \(tcPath). You can try `swiftly uninstall \(toolchain)` to uninstall it and then `swiftly install \(toolchain)` to install it again."
            )
        }

        let path = ProcessInfo.processInfo.environment["PATH"] ?? ""
        var pathComponents = path.split(separator: ":").map { String($0) }

        // The toolchain goes to the beginning of the PATH
        pathComponents.removeAll(where: { $0 == tcPath.string })
        pathComponents = [tcPath.string] + pathComponents

        // Remove swiftly bin directory from the PATH entirely
        let swiftlyBinDir = self.swiftlyBinDir(ctx)
        pathComponents.removeAll(where: { $0 == swiftlyBinDir.string })

        environment = environment.updating(["PATH": String(pathComponents.joined(separator: ":"))])
        environment = try await self.updateEnvironmentWithToolchain(ctx, environment, toolchain, path: String(pathComponents.joined(separator: ":")))

        return environment
    }

#elseif os(Windows)
    public func proxyEnvironment(_ ctx: SwiftlyCoreContext, env: Environment, toolchain: ToolchainVersion) async throws -> Environment {
        var environment = env

        let tcPath = try await self.findToolchainBinDir(ctx, toolchain)
        guard try await fs.exists(atPath: tcPath) else {
            throw SwiftlyError(
                message:
                "Toolchain \(toolchain) could not be located in \(tcPath). You can try `swiftly uninstall \(toolchain)` to uninstall it and then `swiftly install \(toolchain)` to install it again."
            )
        }

        // ProcessEnv's keys ignore case on Windows, so this finds the variable whether the parent
        // passed it as Path or, like Git Bash, as PATH.
        let path = ProcessEnv.block["Path"] ?? ""
        var pathComponents = path.split(separator: ";").map { String($0) }

        // The toolchain goes to the beginning of the Path. Entries compare as FilePath, which treats
        // forward and backward slashes alike and drops a trailing one.
        pathComponents.removeAll(where: { FilePath($0) == tcPath })
        // TODO: add runtimes path too after toolchain path. Can compute or maybe add it from other places later
        pathComponents = [tcPath.string] + pathComponents

        // Remove swiftly bin directory from the Path entirely
        let swiftlyBinDir = self.swiftlyBinDir(ctx)
        pathComponents.removeAll(where: { FilePath($0) == swiftlyBinDir })

        environment = environment.updating(["Path": String(pathComponents.joined(separator: ";"))])
        // TEMP: show the Path the toolchain command gets
        await ctx.printError("swiftly: Path=\(pathComponents.joined(separator: ";"))")

        environment = try await self.updateEnvironmentWithToolchain(ctx, environment, toolchain, path: String(pathComponents.joined(separator: ";")))

        return environment
    }

#endif
}
