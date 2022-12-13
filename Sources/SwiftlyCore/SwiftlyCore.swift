import Foundation

/// The location on disk where swiftly will store its configuration, installed toolchains, and symlinks to
/// the active location.
///
/// The structure of this directory looks like the following:
///
/// ```
/// homeDir/
///   |
///   -- bin/
///   |
///   -- toolchains/
///   |
///   -- config.json
/// ```
///
/// TODO: support other locations besides ~/.swiftly
public var homeDir =
    FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".swiftly", isDirectory: true)

/// The "bin" subdirectory of swiftly's home directory. Contains the swiftly executable as well as symlinks
/// to executables in the "bin" directory of the active toolchain.
public var binDir: URL {
    SwiftlyCore.homeDir.appendingPathComponent("bin", isDirectory: true)
}

/// The "toolchains" subdirectory of swiftly's home directory. Contains the Swift toolchains managed by swiftly.
public var toolchainsDir: URL {
    SwiftlyCore.homeDir.appendingPathComponent("toolchains", isDirectory: true)
}

/// The URL of the configuration file in swiftly's home directory.
public var configFile: URL {
    SwiftlyCore.homeDir.appendingPathComponent("config.json")
}

/// The list of directories that swiftly needs to exist in order to execute.
/// If they do not exist when a swiftly command is invoked, they will be created.
public var requiredDirectories: [URL] {
    [
        SwiftlyCore.homeDir,
        SwiftlyCore.binDir,
        SwiftlyCore.toolchainsDir,
    ]
}

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
    print(prompt, terminator: ": ")
    guard let provider = SwiftlyCore.inputProvider else {
        return Swift.readLine(strippingNewline: true)
    }
    return provider.readLine()
}
