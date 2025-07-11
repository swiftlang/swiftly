import Foundation
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
    public let exitCode: Int32
    public let program: String
    public let arguments: [String]
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
    func proxyEnv(_ ctx: SwiftlyCoreContext, env: [String: String], toolchain: ToolchainVersion) async throws -> [String: String] {
        var newEnv = env

        let tcPath = try await self.findToolchainLocation(ctx, toolchain) / "usr/bin"
        guard try await fs.exists(atPath: tcPath) else {
            throw SwiftlyError(
                message:
                "Toolchain \(toolchain) could not be located in \(tcPath). You can try `swiftly uninstall \(toolchain)` to uninstall it and then `swiftly install \(toolchain)` to install it again."
            )
        }

        var pathComponents = (newEnv["PATH"] ?? "").split(separator: ":").map { String($0) }

        // The toolchain goes to the beginning of the PATH
        pathComponents.removeAll(where: { $0 == tcPath.string })
        pathComponents = [tcPath.string] + pathComponents

        // Remove swiftly bin directory from the PATH entirely
        let swiftlyBinDir = self.swiftlyBinDir(ctx)
        pathComponents.removeAll(where: { $0 == swiftlyBinDir.string })

        newEnv["PATH"] = String(pathComponents.joined(separator: ":"))

        return newEnv
    }

    /// Proxy the invocation of the provided command to the chosen toolchain.
    ///
    /// In the case where the command exit with a non-zero exit code a RunProgramError is thrown with
    /// the exit code and program information.
    ///
    public func proxy(_ ctx: SwiftlyCoreContext, _ toolchain: ToolchainVersion, _ command: String, _ arguments: [String], _ env: [String: String] = [:]) async throws {
        let tcPath = (try await self.findToolchainLocation(ctx, toolchain)) / "usr/bin"

        let commandTcPath = tcPath / command
        let commandToRun = if try await fs.exists(atPath: commandTcPath) {
            commandTcPath.string
        } else {
            command
        }

        var newEnv = try await self.proxyEnv(ctx, env: ProcessInfo.processInfo.environment, toolchain: toolchain)
        for (key, value) in env {
            newEnv[key] = value
        }

#if os(macOS)
        // On macOS, we try to set SDKROOT if its empty for tools like clang++ that need it to
        // find standard libraries that aren't in the toolchain, like libc++. Here we
        // use xcrun to tell us what the default sdk root should be.
        if newEnv["SDKROOT"] == nil {
            newEnv["SDKROOT"] = (try? await self.runProgramOutput("/usr/bin/xcrun", "--show-sdk-path"))?.replacingOccurrences(of: "\n", with: "")
        }
#endif

        try self.runProgram([commandToRun] + arguments, env: newEnv)
    }

    /// Proxy the invocation of the provided command to the chosen toolchain and capture the output.
    ///
    /// In the case where the command exit with a non-zero exit code a RunProgramError is thrown with
    /// the exit code and program information.
    ///
    public func proxyOutput(_ ctx: SwiftlyCoreContext, _ toolchain: ToolchainVersion, _ command: String, _ arguments: [String]) async throws -> String? {
        let tcPath = (try await self.findToolchainLocation(ctx, toolchain)) / "usr/bin"

        let commandTcPath = tcPath / command
        let commandToRun = if try await fs.exists(atPath: commandTcPath) {
            commandTcPath.string
        } else {
            command
        }

        return try await self.runProgramOutput(commandToRun, arguments, env: self.proxyEnv(ctx, env: ProcessInfo.processInfo.environment, toolchain: toolchain))
    }

    /// Run a program.
    ///
    /// In the case where the command exit with a non-zero exit code a RunProgramError is thrown with
    /// the exit code and program information.
    ///
    public func runProgram(_ args: String..., quiet: Bool = false, env: [String: String]? = nil)
        throws
    {
        try self.runProgram([String](args), quiet: quiet, env: env)
    }

    /// Run a program.
    ///
    /// In the case where the command exit with a non-zero exit code a RunProgramError is thrown with
    /// the exit code and program information.
    ///
    public func runProgram(_ args: [String], quiet: Bool = false, env: [String: String]? = nil)
        throws
    {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = args

        if let env {
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

        defer {
            if pgid != -1 {
                tcsetpgrp(STDOUT_FILENO, pgid)
            }
        }

        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw RunProgramError(exitCode: process.terminationStatus, program: args.first!, arguments: Array(args.dropFirst()))
        }
    }

    /// Run a program and capture its output.
    ///
    /// In the case where the command exit with a non-zero exit code a RunProgramError is thrown with
    /// the exit code and program information.
    ///
    public func runProgramOutput(_ program: String, _ args: String..., env: [String: String]? = nil)
        async throws -> String?
    {
        try await self.runProgramOutput(program, [String](args), env: env)
    }

    /// Run a program and capture its output.
    ///
    /// In the case where the command exit with a non-zero exit code a RunProgramError is thrown with
    /// the exit code and program information.
    ///
    public func runProgramOutput(_ program: String, _ args: [String], env: [String: String]? = nil)
        async throws -> String?
    {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [program] + args

        if let env {
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
        defer {
            if pgid != -1 {
                tcsetpgrp(STDOUT_FILENO, pgid)
            }
        }

        let outData = try outPipe.fileHandleForReading.readToEnd()

        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw RunProgramError(exitCode: process.terminationStatus, program: program, arguments: args)
        }

        if let outData {
            return String(data: outData, encoding: .utf8)
        } else {
            return nil
        }
    }

    // Install ourselves in the final location
    public func installSwiftlyBin(_ ctx: SwiftlyCoreContext) async throws {
        // First, let's find out where we are.
        let cmd = CommandLine.arguments[0]

        var cmdAbsolute: FilePath?

        if cmd.hasPrefix("/") {
            cmdAbsolute = FilePath(cmd)
        } else {
            let pathEntries = ([fs.cwd.string] + (ProcessInfo.processInfo.environment["PATH"]?.components(separatedBy: ":") ?? [])).map
                {
                    FilePath($0) / cmd
                }

            for pathEntry in pathEntries {
                if try await fs.exists(atPath: pathEntry) {
                    cmdAbsolute = pathEntry
                    break
                }
            }
        }

        // We couldn't find ourselves in the usual places. Assume that no installation is necessary
        // since we were most likely invoked at SWIFTLY_BIN_DIR already.
        guard let cmdAbsolute else {
            return
        }

        // If swiftly is symlinked then we leave it where it is, such as in a homebrew installation.
        if let _ = try? FileManager.default.destinationOfSymbolicLink(atPath: cmdAbsolute) {
            return
        }

        // Proceed to installation only if we're in the user home directory, or a non-system location.
        let userHome = fs.home

        let systemRoots: [FilePath] = ["/usr", "/opt", "/bin"]

        guard cmdAbsolute.starts(with: userHome) || systemRoots.filter({ cmdAbsolute.starts(with: $0) }).first == nil else {
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

        // First, let's find out where we are.
        let cmd = CommandLine.arguments[0]
        var cmdAbsolute: FilePath?
        if cmd.hasPrefix("/") {
            cmdAbsolute = FilePath(cmd)
        } else {
            let pathEntries = ([fs.cwd.string] + (ProcessInfo.processInfo.environment["PATH"]?.components(separatedBy: ":") ?? [])).map
                {
                    FilePath($0) / cmd
                }

            for pathEntry in pathEntries {
                if try await fs.exists(atPath: pathEntry) {
                    cmdAbsolute = pathEntry
                    break
                }
            }
        }

        // We couldn't find ourselves in the usual places, so if we're not going to be installing
        // swiftly then we can assume that we are running from the final location.
        let homeBinExists = try await fs.exists(atPath: swiftlyHomeBin)
        if cmdAbsolute == nil && homeBinExists {
            return swiftlyHomeBin
        }

        // If swiftly is a symlink then something else, such as homebrew, is managing it.
        if cmdAbsolute != nil {
            if let _ = try? FileManager.default.destinationOfSymbolicLink(atPath: cmdAbsolute!) {
                return cmdAbsolute
            }
        }

        let systemRoots: [FilePath] = ["/usr", "/opt", "/bin"]

        // If we are system managed then we know where swiftly should be.
        let userHome = fs.home

        if let cmdAbsolute, !cmdAbsolute.starts(with: userHome) && systemRoots.filter({ cmdAbsolute.starts(with: $0) }).first != nil {
            return cmdAbsolute
        }

        // If we're running inside an xctest then we don't have a location for this swiftly.
        guard let cmdAbsolute,
              !(
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

#endif
}
