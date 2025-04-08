import ArgumentParser
import Foundation
import SwiftlyCore

struct Run: SwiftlyCommand {
    public static let configuration = CommandConfiguration(
        abstract: "Run a command while proxying to the selected toolchain commands."
    )

    @Argument(parsing: .captureForPassthrough, help: ArgumentHelp(
        "Run a command while proxying to the selected toolchain commands.",
        discussion: """

        Run a command with a selected toolchain. The toolchain commands \
        become the default in the system path.

        You can run one of the usual toolchain commands directly:

            $ swiftly run swift build

        Or you can run another program (or script) that runs one or more toolchain commands:

            $ CC=clang swiftly run make  # Builds targets using clang
            $ swiftly run ./build-things.sh  # Script invokes 'swift build' to create certain product binaries

        Toolchain selection is determined by swift version files `.swift-version`, with a default global \
        as the fallback. See the `swiftly use` command for more details.

        You can also override the selection mechanisms temporarily for the duration of the command using \
        a special syntax. An argument prefixed with a '+' will be treated as the selector.

            $ swiftly run swift build +latest
            $ swiftly run swift build +5.10.1

        The first command builds the swift package with the latest toolchain and the second selects the \
        5.10.1 toolchain. Note that if these aren't installed then run will fail with an error message. \
        You can pre-install the toolchain using `swiftly install <toolchain>` to ensure success.

        If the command that you are running needs the arguments with the '+' prefixes then you can escape \
        it by doubling the '++'.

            $ swiftly run ./myscript.sh ++abcde

        The script will receive the argument as '+abcde'. If there are multiple arguments with the '+' prefix \
        that should be escaped you can disable the selection using a '++' argument, which turns off any \
        selector argument processing for subsequent arguments. This is analogous to the '--' that turns off \
        flag and option processing for subsequent arguments in many argument parsers.

            $ swiftly run ./myscript.sh ++ +abcde +xyz

        The script will receive the argument '+abcde' followed by '+xyz'.
        """
    ))
    var command: [String]

    mutating func run() async throws {
        try await self.run(Swiftly.createDefaultContext())
    }

    mutating func run(_ ctx: SwiftlyCoreContext) async throws {
        try validateSwiftly(ctx)

        // Handle the specific case where help is requested of the run subcommand
        if command == ["--help"] {
            throw CleanExit.helpRequest(self)
        }

        var config = try Config.load(ctx)

        let (command, selector) = try Self.extractProxyArguments(command: self.command)

        let toolchain: ToolchainVersion?

        if let selector {
            let matchedToolchain = config.listInstalledToolchains(selector: selector).max()
            guard let matchedToolchain else {
                throw SwiftlyError(message: "The selected toolchain \(selector.description) didn't match any of the installed toolchains. You can install it with `swiftly install \(selector.description)`")
            }

            toolchain = matchedToolchain
        } else {
            let (version, result) = try await selectToolchain(ctx, config: &config)

            // Abort on any errors relating to swift version files
            if case let .swiftVersionFile(_, _, error) = result, let error {
                throw error
            }

            toolchain = version
        }

        guard let toolchain else {
            throw SwiftlyError(message: "No installed swift toolchain is selected from either from a .swift-version file, or the default. You can try using one that's already installed with `swiftly use <toolchain version>` or install a new toolchain to use with `swiftly install --use <toolchain version>`.")
        }

        do {
            if let outputHandler = ctx.outputHandler {
                if let output = try await Swiftly.currentPlatform.proxyOutput(ctx, toolchain, command[0], [String](command[1...])) {
                    for line in output.split(separator: "\n") {
                        await outputHandler.handleOutputLine(String(line))
                    }
                }
                return
            }

            try await Swiftly.currentPlatform.proxy(ctx, toolchain, command[0], [String](command[1...]))
        } catch let terminated as RunProgramError {
            Foundation.exit(terminated.exitCode)
        } catch {
            throw error
        }
    }

    public static func extractProxyArguments(command: [String]) throws -> (command: [String], selector: ToolchainSelector?) {
        var args: (command: [String], selector: ToolchainSelector?) = (command: [], nil)

        var disableEscaping = false

        for c in command {
            if !disableEscaping && c == "++" {
                disableEscaping = true
                continue
            }

            if !disableEscaping && c.hasPrefix("++") {
                args.command.append("+\(String(c.dropFirst(2)))")
                continue
            }

            if !disableEscaping && c.hasPrefix("+") {
                args.selector = try ToolchainSelector(parsing: String(c.dropFirst()))
                continue
            }

            args.command.append(c)
        }

        guard args.command.count > 0 else {
            throw SwiftlyError(message: "Provide at least one command to run.")
        }

        return args
    }
}
