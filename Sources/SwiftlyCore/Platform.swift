import Foundation

public protocol Platform {
    /// The name of the platform as it is used in the Swift download URLs.
    /// For instance, for Ubuntu 16.04 this would return “ubuntu1604”.
    /// For macOS / Xcode, this would return “xcode”.
    var name: String { get }

    /// The full name of the platform as it is used in the Swift download URLs.
    /// For instance, for Ubuntu 16.04 this would return “ubuntu16.04”.
    var nameFull: String { get }

    /// A human-readable / pretty-printed version of the platform’s name, used for terminal
    /// output and logging.
    /// For example, “Ubuntu 18.04” would be returned on Ubuntu 18.04.
    var namePretty: String { get }

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
    func uninstall(version: ToolchainVersion) throws

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

public struct SystemDependency {}

public struct Snapshot: Decodable {}
