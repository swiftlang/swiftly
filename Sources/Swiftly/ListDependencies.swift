import ArgumentParser
import Foundation
import SwiftlyCore

struct ListDependencies: SwiftlyCommand {
    public static let configuration = CommandConfiguration(
        abstract: "List toolchain dependencies required for the given platform."
    )

    @Option(name: .long, help: "Output format (text, json)")
    var format: SwiftlyCore.OutputFormat = .text

    internal static var allowedInstallCommands: Regex<(Substring, Substring, Substring)> { try! Regex("^(apt-get|yum) -y install( [A-Za-z0-9:\\-\\+]+)+$") }

    mutating func run() async throws {
        try await self.run(Swiftly.createDefaultContext(format: self.format))
    }

    mutating func run(_ ctx: SwiftlyCoreContext) async throws {
        let versionUpdateReminder = try await validateSwiftly(ctx)
        defer {
            versionUpdateReminder()
        }
        try await validateLinked(ctx)

        var config = try await Config.load(ctx)

        // Get the dependencies which must be required for this platform
        let dependencies = try await Swiftly.currentPlatform.getSystemPrerequisites(platformName: config.platform.name)
        let packageManager = try await Swiftly.currentPlatform.getSystemPackageManager(platformName: config.platform.name)
        
        // Determine which dependencies are missing and which are installed
        var installedDeps: [String] = []
        var missingDeps: [String] = []
        for dependency in dependencies {
            if await Swiftly.currentPlatform.isSystemPackageInstalled(packageManager, dependency) {
                installedDeps.append(dependency)
            } else {
                missingDeps.append(dependency)
            }
        }

        try await ctx.output(
            ToolchainDependencyInfo(installedDependencies: installedDeps, missingDependencies: missingDeps)
        )
        
        if !missingDeps.isEmpty, let packageManager {
            let installCmd = "\(packageManager) -y install \(missingDeps.joined(separator: " "))"

            let msg = """

            For your convenience, would you like swiftly to attempt to use elevated permissions to run the following command in order to install the missing toolchain dependencies (This prompt can be suppressed with the
            '--install-system-deps'/'-i' option):
            '\(installCmd)'
            """
            // ToDo: make dynamic via an arg
            let promptForConfirmation = true

            if promptForConfirmation {
                await ctx.message(msg)
                
                guard await ctx.promptForConfirmation(defaultBehavior: true) else {
                    throw SwiftlyError(message: "System dependency installation has been cancelled")
                }
            } else {
                await ctx.message("Swiftly will run the following command with elevated permissions: \(installCmd)")
            }

            // This is very security sensitive code here and that's why there's special process handling
            // and an allow-list of what we will attempt to run as root. Also, the sudo binary is run directly
            // with a fully-qualified path without any checking in order to avoid TOCTOU.
            guard try Self.allowedInstallCommands.wholeMatch(in: installCmd) != nil else {
                fatalError("Command \(installCmd) does not match allowed patterns for sudo")
            }

            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
            p.arguments = ["-k"] + ["-p", "Enter your sudo password to run the dependency install command right away (Ctrl-C aborts): "] + installCmd.split(separator: " ").map { String($0) }
            do {
                try p.run()
                // Attach this process to our process group so that Ctrl-C and other signals work
                let pgid = tcgetpgrp(STDOUT_FILENO)
                if pgid != -1 {
                    tcsetpgrp(STDOUT_FILENO, p.processIdentifier)
                }
                defer { if pgid != -1 {
                    tcsetpgrp(STDOUT_FILENO, pgid)
                }}
                p.waitUntilExit()
                if p.terminationStatus != 0 {
                    throw SwiftlyError(message: "")
                }
            } catch {
                throw SwiftlyError(message: "Error: sudo could not be run to install the packages. You will need to run the dependency install command manually.")
            }
        }
    }
}
