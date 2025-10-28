import Foundation
import Subprocess
#if os(macOS)
import System
#endif

import SystemPackage

extension Platform {
#if os(macOS) || os(Linux)
    func proxyEnv(_ ctx: SwiftlyCoreContext, env: [String: String], toolchain: ToolchainVersion) async throws -> [String: String] {
        var newEnv = env

        let tcPath = try await self.findToolchainLocation(ctx, toolchain) / "usr/bin"
        guard try await fs.exists(atPath: tcPath) else {
            throw SwiftlyError(
                message:
                "Toolchain \(toolchain) could not be located in \(tcPath). You can try `swiftly uninstall \(toolchain)` to uninstall it and then `swiftly install \(toolchain)` to install it again."
            )
        }

        var pathComponents = (newEnv["PATH"] ?? "").split(separator: ":").map { String($0) }

        // The toolchain goes to the beginning of the PATH
        pathComponents.removeAll(where: { $0 == tcPath.string })
        pathComponents = [tcPath.string] + pathComponents

        // Remove swiftly bin directory from the PATH entirely
        let swiftlyBinDir = self.swiftlyBinDir(ctx)
        pathComponents.removeAll(where: { $0 == swiftlyBinDir.string })

        newEnv["PATH"] = String(pathComponents.joined(separator: ":"))

        return newEnv
    }

    /// Proxy the invocation of the provided command to the chosen toolchain.
    ///
    /// In the case where the command exit with a non-zero exit code a RunProgramError is thrown with
    /// the exit code and program information.
    ///
    public func proxy(_ ctx: SwiftlyCoreContext, _ toolchain: ToolchainVersion, _ command: String, _ arguments: [String], _ env: [String: String] = [:]) async throws {
        let tcPath = (try await self.findToolchainLocation(ctx, toolchain)) / "usr/bin"

        let commandTcPath = tcPath / command
        let commandToRun = if try await fs.exists(atPath: commandTcPath) {
            commandTcPath.string
        } else {
            command
        }

        var newEnv = try await self.proxyEnv(ctx, env: ProcessInfo.processInfo.environment, toolchain: toolchain)
        for (key, value) in env {
            newEnv[key] = value
        }

#if os(macOS)
        // On macOS, we try to set SDKROOT if its empty for tools like clang++ that need it to
        // find standard libraries that aren't in the toolchain, like libc++. Here we
        // use xcrun to tell us what the default sdk root should be.
        if newEnv["SDKROOT"] == nil {
            newEnv["SDKROOT"] = (try? await self.runProgramOutput("/usr/bin/xcrun", "--show-sdk-path"))?.replacingOccurrences(of: "\n", with: "")
        }
#endif

        try await self.runProgram([commandToRun] + arguments, env: newEnv)
    }

    /// Proxy the invocation of the provided command to the chosen toolchain and capture the output.
    ///
    /// In the case where the command exit with a non-zero exit code a RunProgramError is thrown with
    /// the exit code and program information.
    ///
    public func proxyOutput(_ ctx: SwiftlyCoreContext, _ toolchain: ToolchainVersion, _ command: String, _ arguments: [String]) async throws -> String? {
        let tcPath = (try await self.findToolchainLocation(ctx, toolchain)) / "usr/bin"

        let commandTcPath = tcPath / command
        let commandToRun = if try await fs.exists(atPath: commandTcPath) {
            commandTcPath.string
        } else {
            command
        }

        return try await self.runProgramOutput(commandToRun, arguments, env: self.proxyEnv(ctx, env: ProcessInfo.processInfo.environment, toolchain: toolchain))
    }

    /// Run a program.
    ///
    /// In the case where the command exit with a non-zero exit code a RunProgramError is thrown with
    /// the exit code and program information.
    ///
    public func runProgram(_ args: String..., quiet: Bool = false, env: [String: String]? = nil)
        async throws
    {
        try await self.runProgram([String](args), quiet: quiet, env: env)
    }

    /// Run a program.
    ///
    /// In the case where the command exit with a non-zero exit code a RunProgramError is thrown with
    /// the exit code and program information.
    ///
    public func runProgram(_ args: [String], quiet: Bool = false, env: [String: String]? = nil)
        async throws
    {
        let environment: Subprocess.Environment = if let env {
            .inherit.updating(
                .init(
                    uniqueKeysWithValues: env.map {
                        (Subprocess.Environment.Key(stringLiteral: $0.key), $0.value)
                    }
                )
            )
        } else {
            .inherit
        }

        if !quiet {
            let result = try await run(
                .path("/usr/bin/env"),
                arguments: .init(args),
                environment: environment,
                input: .fileDescriptor(.standardInput, closeAfterSpawningProcess: false),
                output: .fileDescriptor(.standardOutput, closeAfterSpawningProcess: false),
                error: .fileDescriptor(.standardError, closeAfterSpawningProcess: false),
            )

            if case let .exited(code) = result.terminationStatus, code != 0 {
                throw RunProgramError(exitCode: code, program: args.first!, arguments: Array(args.dropFirst()))
            }
        } else {
            let result = try await run(
                .path("/usr/bin/env"),
                arguments: .init(args),
                environment: environment,
                output: .discarded,
                error: .discarded,
            )

            if case let .exited(code) = result.terminationStatus, code != 0 {
                throw RunProgramError(exitCode: code, program: args.first!, arguments: Array(args.dropFirst()))
            }
        }

        // TODO: handle exits with a signal
    }

    /// Run a program and capture its output.
    ///
    /// In the case where the command exit with a non-zero exit code a RunProgramError is thrown with
    /// the exit code and program information.
    ///
    public func runProgramOutput(_ program: String, _ args: String..., env: [String: String]? = nil)
        async throws -> String?
    {
        try await self.runProgramOutput(program, [String](args), env: env)
    }

    /// Run a program and capture its output.
    ///
    /// In the case where the command exit with a non-zero exit code a RunProgramError is thrown with
    /// the exit code and program information.
    ///
    public func runProgramOutput(_ program: String, _ args: [String], env: [String: String]? = nil)
        async throws -> String?
    {
        let environment: Subprocess.Environment = if let env {
            .inherit.updating(
                .init(
                    uniqueKeysWithValues: env.map {
                        (Subprocess.Environment.Key(stringLiteral: $0.key), $0.value)
                    }
                )
            )
        } else {
            .inherit
        }

        let result = try await run(
            .path("/usr/bin/env"),
            arguments: .init([program] + args),
            environment: environment,
            output: .string(limit: 10 * 1024 * 1024, encoding: UTF8.self),
            error: .fileDescriptor(.standardError, closeAfterSpawningProcess: false)
        )

        if case let .exited(code) = result.terminationStatus, code != 0 {
            throw RunProgramError(exitCode: code, program: args.first!, arguments: Array(args.dropFirst()))
        }

        return result.standardOutput
    }

#endif
}
