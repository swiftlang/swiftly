import Foundation

public let version = SwiftlyVersion(major: 1, minor: 1, patch: 0, suffix: "dev")

/// Protocol defining a handler for information swiftly intends to print to stdout.
/// This is currently only used to intercept print statements for testing.
public protocol OutputHandler {
    func handleOutputLine(_ string: String)
}

/// Protocol defining a provider for information swiftly intends to read from stdin.
public protocol InputProvider {
    func readLine() -> String?
}

/// This struct provides a actor-specific and mockable context for swiftly.
public struct SwiftlyCoreContext {
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

    public init(httpClient: SwiftlyHTTPClient) {
        self.httpClient = httpClient
        self.currentDirectory = URL.currentDirectory()
    }

    public init(
        mockedHomeDir: URL?,
        httpClient: SwiftlyHTTPClient,
        outputHandler: (any OutputHandler)?,
        inputProvider: (any InputProvider)?
    ) {
        self.mockedHomeDir = mockedHomeDir
        self.currentDirectory = mockedHomeDir ?? URL.currentDirectory()
        self.httpClient = httpClient
        self.outputHandler = outputHandler
        self.inputProvider = inputProvider
    }
}

/// Pass the provided string to the set output handler if any.
/// If no output handler has been set, just print to stdout.
public func print(_ ctx: SwiftlyCoreContext, _ string: String = "", terminator: String? = nil) {
    guard let handler = ctx.outputHandler else {
        if let terminator {
            Swift.print(string, terminator: terminator)
        } else {
            Swift.print(string)
        }
        return
    }
    handler.handleOutputLine(string + (terminator ?? ""))
}

public func readLine(_ ctx: SwiftlyCoreContext, prompt: String) -> String? {
    print(prompt, terminator: ": \n")
    guard let provider = ctx.inputProvider else {
        return Swift.readLine(strippingNewline: true)
    }
    return provider.readLine()
}

#if arch(x86_64)
public let cpuArch = Components.Schemas.Architecture.x8664
#elseif arch(arm64)
public let cpuArch = Components.Schemas.Architecture.aarch64
#else
#error("Unsupported processor architecture")
#endif
