import Foundation

public protocol Platform {
    /// The name of the platform as it is used in the Swift download URLs.
    /// For instance, for Ubuntu 16.04 this would return “ubuntu1604”.
    /// For macOS / Xcode, this would return “xcode”.
    var name: String { get }

    /// A human-readable / pretty-printed version of the platform’s name, used for terminal
    /// output and logging.
    /// For example, “Ubuntu 18.04” would be returned on Ubuntu 18.04.
    var namePretty: String { get }

    /// Downloads a toolchain associated with the given version and returns
    /// a URL pointing to where it was downloaded to, which will be a temporary location.
    /// To get the URL to download from, name() and the provided version can be used.
    ///
    /// This will likely be the same on all platforms, so it’ll either have a default implementation
    /// or be omitted from the actual protocol.
    func download(version: String) async throws -> URL

    /// Checks whether a given system dependency has been installed yet or not.
    /// This will only really be used on Linux.
    func isSystemDependencyPresent(_ dependency: SystemDependency) -> Bool

    /// Installs a toolchain from a file on disk pointed to by the given URL.
    /// After this completes, a user can “use” the toolchain.
    func install(from: URL, version: String) throws

    /// Uninstalls a toolchain associated with the given version.
    /// If this version is in use, the next latest version will be used afterwards.
    func uninstall(version: String) throws

    /// Select the toolchain associated with the given version.
    func use(version: String) throws

    /// List the installed toolchains.
    func listToolchains(selector: ToolchainSelector?) -> [ToolchainVersion]

    /// Get a list of snapshot builds for the platform. If a version is specified, only
    /// return snapshots associated with the version.
    /// This will likely have a default implementation.
    func listAvailableSnapshots(version: String) async -> [Snapshot]

    /// Update swiftly itself, if a new version has been released.
    /// This will likely have a default implementation.
    func selfUpdate() async throws
}

public struct SystemDependency {}

public struct Snapshot: Decodable {}