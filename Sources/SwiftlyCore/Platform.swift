import Foundation
import Subprocess
import SystemPackage

public struct PlatformDefinition: Codable, Equatable, Sendable {
    /// The name of the platform as it is used in the Swift download URLs.
    /// For instance, for Ubuntu 16.04 this would return “ubuntu1604”.
    /// For macOS / Xcode, this would return “xcode”.
    public let name: String

    /// The full name of the platform as it is used in the Swift download URLs.
    /// For instance, for Ubuntu 16.04 this would return “ubuntu16.04”.
    public let nameFull: String

    /// A human-readable / pretty-printed version of the platform’s name, used for terminal
    /// output and logging.
    /// For example, “Ubuntu 18.04” would be returned on Ubuntu 18.04.
    public let namePretty: String

    public init(name: String, nameFull: String, namePretty: String) {
        self.name = name
        self.nameFull = nameFull
        self.namePretty = namePretty
    }

    public static let macOS = PlatformDefinition(name: "xcode", nameFull: "osx", namePretty: "macOS")

    public static let ubuntu2404 = PlatformDefinition(
        name: "ubuntu2404", nameFull: "ubuntu24.04", namePretty: "Ubuntu 24.04"
    )
    public static let ubuntu2204 = PlatformDefinition(
        name: "ubuntu2204", nameFull: "ubuntu22.04", namePretty: "Ubuntu 22.04"
    )
    public static let ubuntu2004 = PlatformDefinition(
        name: "ubuntu2004", nameFull: "ubuntu20.04", namePretty: "Ubuntu 20.04"
    )
    public static let ubuntu1804 = PlatformDefinition(
        name: "ubuntu1804", nameFull: "ubuntu18.04", namePretty: "Ubuntu 18.04"
    )
    public static let rhel9 = PlatformDefinition(name: "ubi9", nameFull: "ubi9", namePretty: "RHEL 9")
    public static let fedora39 = PlatformDefinition(
        name: "fedora39", nameFull: "fedora39", namePretty: "Fedora Linux 39"
    )
    public static let amazonlinux2 = PlatformDefinition(
        name: "amazonlinux2", nameFull: "amazonlinux2", namePretty: "Amazon Linux 2"
    )
    public static let debian12 = PlatformDefinition(
        name: "debian12", nameFull: "debian12", namePretty: "Debian GNU/Linux 12"
    )
}

public struct RunProgramError: Swift.Error {
    public let terminationStatus: TerminationStatus
    public let config: Configuration

    public init(terminationStatus: TerminationStatus, config: Configuration) {
        self.terminationStatus = terminationStatus
        self.config = config
    }
}

public protocol Platform: Sendable {
    /// The platform-specific default location on disk for swiftly's home
    /// directory.
    var defaultSwiftlyHomeDir: FilePath { get }

    /// The directory which stores the swiftly executable itself as well as symlinks
    /// to executables in the "bin" directory of the active toolchain.
    ///
    /// If a mocked home directory is set, this will be the "bin" subdirectory of the home directory.
    /// If not, this will be the SWIFTLY_BIN_DIR environment variable if set. If that's also unset,
    /// this will default to the platform's default location.
    func swiftlyBinDir(_ ctx: SwiftlyCoreContext) -> FilePath

    /// The "toolchains" subdirectory that contains the Swift toolchains managed by swiftly.
    func swiftlyToolchainsDir(_ ctx: SwiftlyCoreContext) -> FilePath

    /// The file extension of the downloaded toolchain for this platform.
    /// e.g. for Linux systems this is "tar.gz" and on macOS it's "pkg".
    var toolchainFileExtension: String { get }

    /// Installs a toolchain from a file on disk pointed to by the given path.
    /// After this completes, a user can “use” the toolchain.
    func install(_ ctx: SwiftlyCoreContext, from: FilePath, version: ToolchainVersion, verbose: Bool)
        async throws

    /// Extract swiftly from the provided downloaded archive and install
    /// ourselves from that.
    func extractSwiftlyAndInstall(_ ctx: SwiftlyCoreContext, from archive: FilePath) async throws

    /// Uninstalls a toolchain associated with the given version.
    /// If this version is in use, the next latest version will be used afterwards.
    func uninstall(_ ctx: SwiftlyCoreContext, _ version: ToolchainVersion, verbose: Bool) async throws

    /// Get the name of the swiftly release binary.
    func getExecutableName() -> String

    /// Verifies that the system meets the requirements for swiftly to be installed on the system.
    func verifySwiftlySystemPrerequisites() async throws

    /// Verifies that the system meets the requirements needed to install a swift toolchain of the provided version.
    ///
    /// `platformName` is the platform name of the system
    /// `version` specifies the version of the swift toolchain that will be installed
    /// `requireSignatureValidation` specifies whether the system's support for toolchain signature validation should be checked.
    ///
    /// If the toolchain can be installed, but has unmet runtime dependencies, then a shell script is returned that the user
    /// can run to install these dependencies, possibly with super user permissions.
    ///
    /// Throws if system does not meet the requirements to perform the install.
    func verifySystemPrerequisitesForInstall(
        _ ctx: SwiftlyCoreContext, platformName: String, version: ToolchainVersion,
        requireSignatureValidation: Bool
    ) async throws -> String?

    /// Downloads the signature file associated with the archive and verifies it matches the downloaded archive.
    /// Throws an error if the signature does not match.
    func verifyToolchainSignature(
        _ ctx: SwiftlyCoreContext, toolchainFile: ToolchainFile, archive: FilePath, verbose: Bool
    )
        async throws

    /// Downloads the signature file associated with the archive and verifies it matches the downloaded archive.
    /// Throws an error if the signature does not match.
    func verifySwiftlySignature(
        _ ctx: SwiftlyCoreContext, archiveDownloadURL: URL, archive: FilePath, verbose: Bool
    ) async throws

    /// Detect the platform definition for this platform.
    func detectPlatform(_ ctx: SwiftlyCoreContext, disableConfirmation: Bool, platform: String?)
        async throws -> PlatformDefinition

    /// Get the user's current login shell
    func getShell() async throws -> String

    /// Find the location where the toolchain should be installed.
    func findToolchainLocation(_ ctx: SwiftlyCoreContext, _ toolchain: ToolchainVersion) async throws -> FilePath

    /// Find the location of the toolchain binaries.
    func findToolchainBinDir(_ ctx: SwiftlyCoreContext, _ toolchain: ToolchainVersion) async throws -> FilePath

    /// Update the process environment used when proxying based on the selected toolchain.
    func updateEnvironmentWithToolchain(_ ctx: SwiftlyCoreContext, _ environment: Environment, _ toolchain: ToolchainVersion) async throws -> Environment
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
    ///   -- toolchains/
    ///   |
    ///   -- config.json
    /// ```
    ///
    public func swiftlyHomeDir(_ ctx: SwiftlyCoreContext) -> FilePath {
        ctx.mockedHomeDir
            ?? ProcessInfo.processInfo.environment["SWIFTLY_HOME_DIR"].map { FilePath($0) }
            ?? self.defaultSwiftlyHomeDir
    }

    /// The path of the configuration file in swiftly's home directory.
    public func swiftlyConfigFile(_ ctx: SwiftlyCoreContext) -> FilePath {
        self.swiftlyHomeDir(ctx) / "config.json"
    }

#if os(macOS) || os(Linux)

    // Install ourselves in the final location
    public func installSwiftlyBin(_ ctx: SwiftlyCoreContext) async throws {
        // We couldn't find ourselves in the usual places. Assume that no installation is necessary
        // since we were most likely invoked at SWIFTLY_BIN_DIR already.
        guard let cmdAbsolute = try await self.absoluteCommandPath() else {
            return
        }

        // Make sure swiftly is not system managed.
        if try await self.isSystemManaged(cmdAbsolute) {
            return
        }

        // Proceed only if we're not running in the context of a mocked home directory.
        guard ctx.mockedHomeDir == nil else {
            return
        }

        // We're already running from where we would be installing ourselves.
        guard
            case let swiftlyHomeBin = self.swiftlyBinDir(ctx) / "swiftly",
            cmdAbsolute != swiftlyHomeBin
        else {
            return
        }

        await ctx.message("Installing swiftly in \(swiftlyHomeBin)...")

        if try await fs.exists(atPath: swiftlyHomeBin) {
            try await fs.remove(atPath: swiftlyHomeBin)
        }

        do {
            try await fs.move(atPath: cmdAbsolute, toPath: swiftlyHomeBin)
        } catch {
            try await fs.copy(atPath: cmdAbsolute, toPath: swiftlyHomeBin)
            await ctx.message(
                "Swiftly has been copied into the installation directory. You can remove '\(cmdAbsolute)'. It is no longer needed."
            )
        }
    }

    // Find the location where swiftly should be executed.
    public func findSwiftlyBin(_ ctx: SwiftlyCoreContext) async throws -> FilePath? {
        let swiftlyHomeBin = self.swiftlyBinDir(ctx) / "swiftly"
        guard let cmdAbsolute = try await self.absoluteCommandPath() else {
            if try await fs.exists(atPath: swiftlyHomeBin) {
                // We couldn't find ourselves in the usual places, so if we're not going to be installing
                // swiftly then we can assume that we are running from the final location.
                return swiftlyHomeBin
            }
            return nil
        }

        if try await self.isSystemManaged(cmdAbsolute) {
            return cmdAbsolute
        }

        // If we're running inside an xctest then we don't have a location for this swiftly.
        guard !(
            (cmdAbsolute.string.hasSuffix("xctest") || cmdAbsolute.string.hasSuffix("swiftpm-testing-helper"))
                && CommandLine.arguments.contains { $0.contains("InstallTests") }
        )
        else {
            return nil
        }

        return try await fs.exists(atPath: swiftlyHomeBin) ? swiftlyHomeBin : nil
    }

    public func findToolchainBinDir(_ ctx: SwiftlyCoreContext, _ toolchain: ToolchainVersion) async throws -> FilePath
    {
        (try await self.findToolchainLocation(ctx, toolchain)) / "usr/bin"
    }

    private func absoluteCommandPath() async throws -> FilePath? {
        let cmd = CommandLine.arguments[0]
        if cmd.hasPrefix("/") {
            return FilePath(cmd)
        }
        let localCmd = FilePath(fs.cwd.string) / cmd
        if try await fs.exists(atPath: localCmd) {
            return localCmd
        }
        guard let path = ProcessInfo.processInfo.environment["PATH"] else {
            return nil
        }
        let pathEntries = path.components(separatedBy: ":").map { FilePath($0) / cmd }
        for pathEntry in pathEntries where try await fs.exists(atPath: pathEntry) {
            return pathEntry
        }
        return nil
    }

    private func isSystemManaged(_ path: FilePath) async throws -> Bool {
        // If swiftly is symlinked then we leave it where it is, such as in a Homebrew installation.
        if try await fs.isSymLink(atPath: path) {
            return true
        }
        if path.starts(with: fs.home) {
            // In user's home directory, so not system managed.
            return false
        }
        // With a system prefix?
        return ["/usr", "/opt", "/bin"].contains { path.starts(with: $0) }
    }

#endif
}
