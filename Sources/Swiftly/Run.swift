import ArgumentParser
import Foundation
import Subprocess
import SwiftlyCore
import SystemPackage

struct Run: SwiftlyCommand {
    public static let configuration = CommandConfiguration(
        abstract: "Run a command while proxying to the selected toolchain commands."
    )

    @OptionGroup var root: GlobalOptions

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
        try await self.run(Swiftly.createDefaultContext(options: self.root))
    }

    mutating func run(_ ctx: SwiftlyCoreContext) async throws {
        try await validateSwiftly(ctx)

        var config = try await Config.load(ctx)

        // Handle the specific case where help is requested of the run subcommand
        if command == ["--help"] || command == ["-h"] {
            throw CleanExit.helpRequest(self)
        }

        // Handle the spcific case where version is requested of the run subcommand
        if command == ["--version"] {
            throw CleanExit.message(String(describing: SwiftlyCore.version))
        }

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

        let env: Environment = try await Swiftly.currentPlatform.proxyEnvironment(ctx, env: .inherit, toolchain: toolchain)

        let commandPath = FilePath(command[0])
        let executable: Executable
        if try await fs.exists(atPath: commandPath) {
            executable = .path(commandPath)
        } else {
            // Search the toolchain ourselves to find the correct executable path. Subprocess's default search
            // paths will interfere with preferring the selected toolchain over system toolchains.
            let tcBinPath = try await Swiftly.currentPlatform.findToolchainLocation(ctx, toolchain) / "usr/bin"
            let toolPath = tcBinPath / command[0]
            if try await fs.exists(atPath: toolPath) && toolPath.isLexicallyNormal {
                executable = .path(toolPath)
            } else {
                executable = .name(command[0])
            }
        }

        let processConfig = Configuration(
            executable: executable,
            arguments: Arguments([String](command[1...])),
            environment: env
        )

        if let outputHandler = ctx.outputHandler {
            let result = try await Subprocess.run(processConfig) { _, output in
                for try await line in output.lines() {
                    await outputHandler.handleOutputLine(line.replacing("\n", with: ""))
                }
            }

            if !result.terminationStatus.isSuccess {
                throw RunProgramError(terminationStatus: result.terminationStatus, config: processConfig)
            }

            return
        }

        let result = try await Subprocess.run(processConfig, input: .standardInput, output: .standardOutput, error: .standardError)
        if !result.terminationStatus.isSuccess {
            throw RunProgramError(terminationStatus: result.terminationStatus, config: processConfig)
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
