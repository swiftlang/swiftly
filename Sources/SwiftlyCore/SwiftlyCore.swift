import Foundation
import SwiftlyWebsiteAPI

public let version = SwiftlyVersion(major: 1, minor: 1, patch: 0, suffix: "dev")

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
    public var mockedHomeDir: URL?

    /// A separate current working directory to use for testing purposes. This overrides
    /// swiftly's default current working directory logic.
    public var currentDirectory: URL

    /// A chosen shell for the current user as a typical path to the shell's binary
    /// location (e.g. /bin/sh). This overrides swiftly's default shell detection mechanisms
    /// for testing purposes.
    public var mockedShell: String?

    /// This is the default http client that swiftly uses for its network
    /// requests.
    public var httpClient: SwiftlyHTTPClient

    /// The output handler to use, if any.
    public var outputHandler: (any OutputHandler)?

    /// The input probider to use, if any
    public var inputProvider: (any InputProvider)?

    public init() {
        self.httpClient = SwiftlyHTTPClient(httpRequestExecutor: HTTPRequestExecutorImpl())
        self.currentDirectory = URL.currentDirectory()
    }

    /// Pass the provided string to the set output handler if any.
    /// If no output handler has been set, just print to stdout.
    public func print(_ string: String = "", terminator: String? = nil) async {
        guard let handler = self.outputHandler else {
            if let terminator {
                Swift.print(string, terminator: terminator)
            } else {
                Swift.print(string)
            }
            return
        }
        await handler.handleOutputLine(string + (terminator ?? ""))
    }

    public func readLine(prompt: String) async -> String? {
        await self.print(prompt, terminator: ": \n")
        guard let provider = self.inputProvider else {
            return Swift.readLine(strippingNewline: true)
        }
        return await provider.readLine()
    }

    public func promptForConfirmation(defaultBehavior: Bool) async -> Bool {
        let options: String
        if defaultBehavior {
            options = "(Y/n)"
        } else {
            options = "(y/N)"
        }

        while true {
            let answer = (await self.readLine(prompt: "Proceed? \(options)") ?? (defaultBehavior ? "y" : "n")).lowercased()

            guard ["y", "n", ""].contains(answer) else {
                await self.print("Please input either \"y\" or \"n\", or press ENTER to use the default.")
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
