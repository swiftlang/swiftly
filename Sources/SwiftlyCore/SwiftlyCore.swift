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
        SwiftlyCore.toolchainsDir
    ]
}

/// This is the list of executables included in a Swift toolchain that swiftly will create symlinks to in its `bin`
/// directory.
///
/// swiftly doesn't create links for every entry in a toolchain's `bin` directory since some of them are
/// forked versions of executables not specific to Swift (e.g. clang), and we don't want to override the users
/// existing installations of those executables.
public let symlinkedExecutables: [String] = [
    "swift",
    "swiftc",
    "sourcekit-lsp",
    "docc"
]
