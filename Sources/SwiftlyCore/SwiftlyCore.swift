import Foundation
import SwiftlyWebsiteAPI
import SystemPackage

public let version = SwiftlyVersion(major: 1, minor: 2, patch: 0, suffix: "dev")

/// Protocol defining a handler for information swiftly intends to print to stdout.
/// This is currently only used to intercept print statements for testing.
public protocol OutputHandler: Actor {
    func handleOutputLine(_ string: String) async
}

/// Protocol defining a provider for information swiftly intends to read from stdin.
public protocol InputProvider: Actor {
    func readLine() async -> String?
}

/// This struct provides a actor-specific and mockable context for swiftly.
public struct SwiftlyCoreContext: Sendable {
    /// A separate home directory to use for testing purposes. This overrides swiftly's default
    /// home directory location logic.
    public var mockedHomeDir: FilePath?

    /// A separate current working directory to use for testing purposes. This overrides
    /// swiftly's default current working directory logic.
    public var currentDirectory: FilePath

    /// A chosen shell for the current user as a typical path to the shell's binary
    /// location (e.g. /bin/sh). This overrides swiftly's default shell detection mechanisms
    /// for testing purposes.
    public var mockedShell: String?

    /// Whether to skip the check for swiftly updates.
    /// This is helpful when offline, as update checks would timeout
    public var skipUpdatesCheck: Bool

    /// This is the default http client that swiftly uses for its network
    /// requests.
    public var httpClient: SwiftlyHTTPClient

    /// The output handler to use, if any.
    public var outputHandler: (any OutputHandler)?

    /// The output handler for error streams
    public var errorOutputHandler: (any OutputHandler)?

    /// The input provider to use, if any
    public var inputProvider: (any InputProvider)?

    /// The terminal info provider
    public var terminal: any Terminal

    /// The format
    public var format: OutputFormat = .text

    public init(
        format: SwiftlyCore.OutputFormat = .text,
        skipUpdatesCheck: Bool = false
    ) {
        self.httpClient = SwiftlyHTTPClient(httpRequestExecutor: HTTPRequestExecutorImpl())
        self.currentDirectory = fs.cwd
        self.format = format
        self.terminal = SystemTerminal()
        self.skipUpdatesCheck = skipUpdatesCheck
    }

    public init(
        httpClient: SwiftlyHTTPClient,
        skipUpdatesCheck: Bool = false
    ) {
        self.httpClient = httpClient
        self.currentDirectory = fs.cwd
        self.terminal = SystemTerminal()
        self.skipUpdatesCheck = skipUpdatesCheck
    }

    /// Pass the provided string to the set output handler if any.
    /// If no output handler has been set, just print to stdout.
    public func print(_ string: String = "") async {
        guard let handler = self.outputHandler else {
            Swift.print(string)
            return
        }
        await handler.handleOutputLine(string)
    }

    public func message(_ string: String = "", terminator: String? = nil, wrap: Bool = true) async {
        let messageString = (wrap ? self.wrappedMessage(string) : string) + (terminator ?? "")

        if self.format == .json {
            await self.printError(messageString)
            return
        } else {
            await self.print(messageString)
        }
    }

    private func wrappedMessage(_ string: String) -> String {
        let terminalWidth = self.terminal.width()
        return string.isEmpty ? string : string.wrapText(to: terminalWidth)
    }

    public func printError(_ string: String = "") async {
        if let handler = self.errorOutputHandler {
            await handler.handleOutputLine(string)
        } else {
            if let data = (string + "\n").data(using: .utf8) {
                try? FileHandle.standardError.write(contentsOf: data)
            }
        }
    }

    public func output(_ data: OutputData) async throws {
        let formattedOutput: String
        switch self.format {
        case .text:
            formattedOutput = TextOutputFormatter().format(data)
        case .json:
            formattedOutput = try JSONOutputFormatter().format(data)
        }
        await self.print(formattedOutput)
    }

    public func readLine(prompt: String) async -> String? {
        await self.message(prompt, terminator: ": \n")
        guard let provider = self.inputProvider else {
            return Swift.readLine(strippingNewline: true)
        }
        return await provider.readLine()
    }

    public func promptForConfirmation(defaultBehavior: Bool) async -> Bool {
        if self.format == .json {
            await self.message("Assuming \(defaultBehavior ? "yes" : "no") due to JSON format")
            return defaultBehavior
        }
        let options: String
        if defaultBehavior {
            options = "(Y/n)"
        } else {
            options = "(y/N)"
        }

        while true {
            let answer =
                (await self.readLine(prompt: "Proceed? \(options)")
                        ?? (defaultBehavior ? "y" : "n")).lowercased()

            guard ["y", "n", ""].contains(answer) else {
                await self.message(
                    "Please input either \"y\" or \"n\", or press ENTER to use the default.")
                continue
            }

            if answer.isEmpty {
                return defaultBehavior
            } else {
                return answer == "y"
            }
        }
    }
}

#if arch(x86_64)
public let cpuArch = SwiftlyWebsiteAPI.Components.Schemas.Architecture.x8664
#elseif arch(arm64)
public let cpuArch = SwiftlyWebsiteAPI.Components.Schemas.Architecture.aarch64
#else
#error("Unsupported processor architecture")
#endif
