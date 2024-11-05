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

    public static let macOS = PlatformDefinition(name: "xcode", nameFull: "osx", namePretty: "macOS")
    public static let ubuntu2204 = PlatformDefinition(name: "ubuntu2204", nameFull: "ubuntu22.04", namePretty: "Ubuntu 22.04")
    public static let ubuntu2004 = PlatformDefinition(name: "ubuntu2004", nameFull: "ubuntu20.04", namePretty: "Ubuntu 20.04")
    public static let ubuntu1804 = PlatformDefinition(name: "ubuntu1804", nameFull: "ubuntu18.04", namePretty: "Ubuntu 18.04")
    public static let rhel9 = PlatformDefinition(name: "ubi9", nameFull: "ubi9", namePretty: "RHEL 9")
    public static let amazonlinux2 = PlatformDefinition(name: "amazonlinux2", nameFull: "amazonlinux2", namePretty: "Amazon Linux 2")
}

public struct RunProgramError: Swift.Error {
    public let exitCode: Int32
    public let program: String
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

    /// Extract swiftly from the provided downloaded archive and install
    /// ourselves from that.
    func extractSwiftlyAndInstall(from archive: URL) throws

    /// Uninstalls a toolchain associated with the given version.
    /// If this version is in use, the next latest version will be used afterwards.
    func uninstall(_ version: ToolchainVersion) throws

    /// Get the name of the swiftly release binary.
    func getExecutableName() -> String

    /// Get a path pointing to a unique, temporary file.
    /// This does not need to actually create the file.
    func getTempFilePath() -> URL

    /// Verifies that the system meets the requirements for swiftly to be installed on the system.
    func verifySwiftlySystemPrerequisites() throws

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
    func verifySystemPrerequisitesForInstall(httpClient: SwiftlyHTTPClient, platformName: String, version: ToolchainVersion, requireSignatureValidation: Bool) async throws -> String?

    /// Downloads the signature file associated with the archive and verifies it matches the downloaded archive.
    /// Throws an error if the signature does not match.
    /// On Linux, signature verification will be skipped if gpg is not installed.
    func verifySignature(httpClient: SwiftlyHTTPClient, archiveDownloadURL: URL, archive: URL) async throws

    /// Detect the platform definition for this platform.
    func detectPlatform(disableConfirmation: Bool, platform: String?) async throws -> PlatformDefinition

    /// Get the user's current login shell
    func getShell() async throws -> String

    /// Find the location where the toolchain should be installed.
    func findToolchainLocation(_ toolchain: ToolchainVersion) -> URL

    /// Find the location of the toolchain binaries.
    func findToolchainBinDir(_ toolchain: ToolchainVersion) -> URL
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
    internal func proxyEnv(_ toolchain: ToolchainVersion) throws -> [String: String] {
        let tcPath = self.findToolchainLocation(toolchain).appendingPathComponent("usr/bin")
        var newEnv = ProcessInfo.processInfo.environment

        // Prevent circularities with a memento environment variable
        guard newEnv["SWIFTLY_PROXY_IN_PROGRESS"] == nil else {
            throw Error(message: "Circular swiftly proxy invocation")
        }
        newEnv["SWIFTLY_PROXY_IN_PROGRESS"] = "1"

        // The toolchain goes to the beginning of the PATH
        var newPath = newEnv["PATH"] ?? ""
        if !newPath.hasPrefix(tcPath.path + ":") {
            newPath = "\(tcPath.path):\(newPath)"
        }
        newEnv["PATH"] = newPath

        return newEnv
    }

    /// Proxy the invocation of the provided command to the chosen toolchain.
    ///
    /// In the case where the command exit with a non-zero exit code a RunProgramError is thrown with
    /// the exit code and program information.
    ///
    public func proxy(_ toolchain: ToolchainVersion, _ command: String, _ arguments: [String]) async throws {
        try self.runProgram([command] + arguments, env: self.proxyEnv(toolchain))
    }

    /// Proxy the invocation of the provided command to the chosen toolchain and capture the output.
    ///
    /// In the case where the command exit with a non-zero exit code a RunProgramError is thrown with
    /// the exit code and program information.
    ///
    public func proxyOutput(_ toolchain: ToolchainVersion, _ command: String, _ arguments: [String]) async throws -> String? {
        try await self.runProgramOutput(command, arguments, env: self.proxyEnv(toolchain))
    }

    /// Run a program.
    ///
    /// In the case where the command exit with a non-zero exit code a RunProgramError is thrown with
    /// the exit code and program information.
    ///
    public func runProgram(_ args: String..., quiet: Bool = false, env: [String: String]? = nil) throws {
        try self.runProgram([String](args), quiet: quiet, env: env)
    }

    /// Run a program.
    ///
    /// In the case where the command exit with a non-zero exit code a RunProgramError is thrown with
    /// the exit code and program information.
    ///
    public func runProgram(_ args: [String], quiet: Bool = false, env: [String: String]? = nil) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = args

        if let env = env {
            process.environment = env
        }

        if quiet {
            process.standardOutput = nil
            process.standardError = nil
        }

        try process.run()
        // Attach this process to our process group so that Ctrl-C and other signals work
        let pgid = tcgetpgrp(STDOUT_FILENO)
        if pgid != -1 {
            tcsetpgrp(STDOUT_FILENO, process.processIdentifier)
        }
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw RunProgramError(exitCode: process.terminationStatus, program: args.first!)
        }
    }

    /// Run a program and capture its output.
    ///
    /// In the case where the command exit with a non-zero exit code a RunProgramError is thrown with
    /// the exit code and program information.
    ///
    public func runProgramOutput(_ program: String, _ args: String..., env: [String: String]? = nil) async throws -> String? {
        try await self.runProgramOutput(program, [String](args), env: env)
    }

    /// Run a program and capture its output.
    ///
    /// In the case where the command exit with a non-zero exit code a RunProgramError is thrown with
    /// the exit code and program information.
    ///
    public func runProgramOutput(_ program: String, _ args: [String], env: [String: String]? = nil) async throws -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [program] + args

        if let env = env {
            process.environment = env
        }

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
            throw RunProgramError(exitCode: process.terminationStatus, program: args.first!)
        }

        if let outData = outData {
            return String(data: outData, encoding: .utf8)
        } else {
            return nil
        }
    }

    public func systemManagedBinary(_ cmd: String) throws -> String? {
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
            throw Error(message: "Could not locate source of \(cmd) binary in either the PATH, relative, or absolute path")
        }

        // If the binary is in the user's home directory, or is not in system locations ("/usr", "/opt", "/bin")
        //  then it is expected to be outside of a system package location and we manage the binary ourselves.
        if bin.hasPrefix(userHome.path + "/") || (!bin.hasPrefix("/usr") && !bin.hasPrefix("/opt") && !bin.hasPrefix("/bin")) {
            return nil
        }

        return bin
    }

    public func findToolchainBinDir(_ toolchain: ToolchainVersion) -> URL {
        self.findToolchainLocation(toolchain).appendingPathComponent("usr/bin")
    }
#endif
}

public struct SystemDependency {}

public struct Snapshot: Decodable {}
