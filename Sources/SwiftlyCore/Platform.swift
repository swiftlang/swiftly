import Foundation

public struct PlatformDefinition: Codable, Equatable {
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
}

public protocol Platform {
    /// The platform-specific location on disk where applications are
    /// supposed to store their custom data.
    var appDataDirectory: URL { get }

    /// The directory which stores the swiftly executable itself as well as symlinks
    /// to executables in the "bin" directory of the active toolchain.
    ///
    /// If a mocked home directory is set, this will be the "bin" subdirectory of the home directory.
    /// If not, this will be the SWIFTLY_BIN_DIR environment variable if set. If that's also unset,
    /// this will default to the platform's default location.
    var swiftlyBinDir: URL { get }

    /// The "toolchains" subdirectory that contains the Swift toolchains managed by swiftly.
    var swiftlyToolchainsDir: URL { get }

    /// The file extension of the downloaded toolchain for this platform.
    /// e.g. for Linux systems this is "tar.gz" and on macOS it's "pkg".
    var toolchainFileExtension: String { get }

    /// Checks whether a given system dependency has been installed yet or not.
    /// This will only really used on Linux.
    func isSystemDependencyPresent(_ dependency: SystemDependency) -> Bool

    /// Installs a toolchain from a file on disk pointed to by the given URL.
    /// After this completes, a user can “use” the toolchain.
    func install(from: URL, version: ToolchainVersion) throws

    /// Uninstalls a toolchain associated with the given version.
    /// If this version is in use, the next latest version will be used afterwards.
    func uninstall(_ version: ToolchainVersion) throws

    /// Select the toolchain associated with the given version.
    /// Returns whether the selection was successful.
    func use(_ version: ToolchainVersion, currentToolchain: ToolchainVersion?) throws -> Bool

    /// Clear the current active toolchain.
    func unUse(currentToolchain: ToolchainVersion) throws

    /// Get a list of snapshot builds for the platform. If a version is specified, only
    /// return snapshots associated with the version.
    /// This will likely have a default implementation.
    func listAvailableSnapshots(version: String?) async -> [Snapshot]

    /// Get the name of the swiftly release binary.
    func getExecutableName() -> String

    /// Get a path pointing to a unique, temporary file.
    /// This does not need to actually create the file.
    func getTempFilePath() -> URL

    /// Verifies that the system meets the requirements needed to install a toolchain.
    /// `requireSignatureValidation` specifies whether the system's support for toolchain signature validation should be verified.
    ///
    /// Throws if system does not meet the requirements.
    func verifySystemPrerequisitesForInstall(requireSignatureValidation: Bool) throws

    /// Downloads the signature file associated with the archive and verifies it matches the downloaded archive.
    /// Throws an error if the signature does not match.
    /// On Linux, signature verification will be skipped if gpg is not installed.
    func verifySignature(httpClient: SwiftlyHTTPClient, archiveDownloadURL: URL, archive: URL) async throws

    /// Detect the platform definition for this platform.
    func detectPlatform(disableConfirmation: Bool, platform: String?) async throws -> PlatformDefinition

    /// Get the user's current login shell
    func getShell() async throws -> String
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
    public var swiftlyHomeDir: URL {
        SwiftlyCore.mockedHomeDir
            ?? ProcessInfo.processInfo.environment["SWIFTLY_HOME_DIR"].map { URL(fileURLWithPath: $0) }
            ?? self.appDataDirectory.appendingPathComponent("swiftly", isDirectory: true)
    }

    /// The URL of the configuration file in swiftly's home directory.
    public var swiftlyConfigFile: URL {
        self.swiftlyHomeDir.appendingPathComponent("config.json")
    }

#if os(macOS) || os(Linux)
    public func runProgram(_ args: String..., quiet: Bool = false) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = args

        if quiet {
            process.standardOutput = nil
            process.standardError = nil
        }

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw Error(message: "\(args.first!) exited with non-zero status: \(process.terminationStatus)")
        }
    }

    public func runProgramOutput(_ program: String, _ args: String...) async throws -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [program] + args

        let outPipe = Pipe()
        process.standardInput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.standardOutput = outPipe

        try process.run()
        // Attach this process to our process group so that Ctrl-C and other signals work
        let pgid = tcgetpgrp(STDOUT_FILENO)
        if pgid != -1 {
            tcsetpgrp(STDOUT_FILENO, process.processIdentifier)
        }
        let outData = try outPipe.fileHandleForReading.readToEnd()

        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw Error(message: "\(args.first!) exited with non-zero status: \(process.terminationStatus)")
        }

        if let outData = outData {
            return String(data: outData, encoding: .utf8)
        } else {
            return nil
        }
    }

    public func isSystemManagedBinary(_ cmd: String) throws -> Bool {
        let userHome = FileManager.default.homeDirectoryForCurrentUser
        let binLocs = [cmd] + ProcessInfo.processInfo.environment["PATH"]!.components(separatedBy: ":").map { $0 + "/" + cmd }
        var bin: String?
        for binLoc in binLocs {
            if FileManager.default.fileExists(atPath: binLoc) {
                bin = binLoc
                break
            }
        }
        guard let bin = bin else {
            throw Error(message: "Could not locate source of swiftly binary to copy into the installation location: \(cmd)")
        }

        // If the binary is in the user's home directory, or is not in system locations ("/usr", "/opt", "/bin")
        //  then it is expected to be outside of a system package location and we manage the binary ourselves.
        if bin.hasPrefix(userHome.path + "/") || (!bin.hasPrefix("/usr") && !bin.hasPrefix("/opt") && !bin.hasPrefix("/bin")) {
            return false
        }

        return true
    }
#endif
}

public struct SystemDependency {}

public struct Snapshot: Decodable {}
