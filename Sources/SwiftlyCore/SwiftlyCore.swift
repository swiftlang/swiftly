import Foundation

public let version = SwiftlyVersion(major: 1, minor: 0, patch: 0)

/// A separate home directory to use for testing purposes. This overrides swiftly's default
/// home directory location logic.
public var mockedHomeDir: URL?

/// This is the default http client that swiftly uses for its network
/// requests.
public var httpClient = SwiftlyHTTPClient()

/// An HTTP request executor that allows different transport level configuration
/// such as allowing a proxy to be configured, or for the purpose of mocking
/// for tests.
public var httpRequestExecutor: HTTPRequestExecutor = HTTPRequestExecutorImpl()

/// Protocol defining a handler for information swiftly intends to print to stdout.
/// This is currently only used to intercept print statements for testing.
public protocol OutputHandler {
    func handleOutputLine(_ string: String)
}

/// The output handler to use, if any.
public var outputHandler: (any OutputHandler)?

/// Pass the provided string to the set output handler if any.
/// If no output handler has been set, just print to stdout.
public func print(_ string: String = "", terminator: String? = nil) {
    guard let handler = SwiftlyCore.outputHandler else {
        if let terminator {
            Swift.print(string, terminator: terminator)
        } else {
            Swift.print(string)
        }
        return
    }
    handler.handleOutputLine(string + (terminator ?? ""))
}

public protocol InputProvider {
    func readLine() -> String?
}

public var inputProvider: (any InputProvider)?

public func readLine(prompt: String) -> String? {
    print(prompt, terminator: ": \n")
    guard let provider = SwiftlyCore.inputProvider else {
        return Swift.readLine(strippingNewline: true)
    }
    return provider.readLine()
}
