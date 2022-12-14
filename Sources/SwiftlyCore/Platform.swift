import Foundation

public protocol Platform {
    /// The platform-specific location on disk where applications are
    /// supposed to store their custom data.
    var appDataDirectory: URL { get }

    /// The file extension of the downloaded toolchain for this platform.
    /// e.g. for Linux systems this is "tar.gz" and on macOS it's "pkg".
    var toolchainFileExtension: String { get }

    /// Checks whether a given system dependency has been installed yet or not.
    /// This will only really be used on Linux.
    func isSystemDependencyPresent(_ dependency: SystemDependency) -> Bool

    /// Installs a toolchain from a file on disk pointed to by the given URL.
    /// After this completes, a user can “use” the toolchain.
    func install(from: URL, version: ToolchainVersion) throws

    /// Uninstalls a toolchain associated with the given version.
    /// If this version is in use, the next latest version will be used afterwards.
    func uninstall(_ version: ToolchainVersion) throws

    /// Select the toolchain associated with the given version.
    func use(_ version: ToolchainVersion) throws

    /// Get a list of snapshot builds for the platform. If a version is specified, only
    /// return snapshots associated with the version.
    /// This will likely have a default implementation.
    func listAvailableSnapshots(version: String?) async -> [Snapshot]

    /// Update swiftly itself, if a new version has been released.
    /// This will likely have a default implementation.
    func selfUpdate() async throws

    /// Get a path pointing to a unique, temporary file.
    /// This does not need to actually create the file.
    func getTempFilePath() -> URL
}

extension Platform {
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
    /// TODO: support other locations besides ~/.local/share/swiftly
    public var swiftlyHomeDir: URL {
        SwiftlyCore.mockedHomeDir ?? self.appDataDirectory.appendingPathComponent("swiftly", isDirectory: true)
    }

    /// The "bin" subdirectory of swiftly's home directory. Contains the swiftly executable as well as symlinks
    /// to executables in the "bin" directory of the active toolchain.
    public var swiftlyBinDir: URL {
        self.swiftlyHomeDir.appendingPathComponent("bin", isDirectory: true)
    }

    /// The "toolchains" subdirectory of swiftly's home directory. Contains the Swift toolchains managed by swiftly.
    public var swiftlyToolchainsDir: URL {
        self.swiftlyHomeDir.appendingPathComponent("toolchains", isDirectory: true)
    }

    /// The URL of the configuration file in swiftly's home directory.
    public var swiftlyConfigFile: URL {
        self.swiftlyHomeDir.appendingPathComponent("config.json")
    }
}

public struct SystemDependency {}

public struct Snapshot: Decodable {}
