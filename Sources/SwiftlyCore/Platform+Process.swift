import Foundation
import Subprocess
#if os(macOS)
import System
#endif

import SystemPackage

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

#if os(macOS)
        // On macOS, we try to set SDKROOT if its empty for tools like clang++ that need it to
        // find standard libraries that aren't in the toolchain, like libc++. Here we
        // use xcrun to tell us what the default sdk root should be.
        if ProcessInfo.processInfo.environment["SDKROOT"] == nil {
            environment = environment.updating([
                "SDKROOT": try? await run(
                    .path(SystemPackage.FilePath("/usr/bin/xcrun")),
                    arguments: ["--show-sdk-path"],
                    output: .string(limit: 1024 * 10)
                ).standardOutput?.replacingOccurrences(of: "\n", with: ""),
            ]
            )
        }
#endif

        return environment
    }

#endif
}
