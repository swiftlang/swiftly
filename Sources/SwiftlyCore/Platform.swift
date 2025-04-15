import Foundation

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
    var defaultSwiftlyHomeDirectory: URL { get }

    /// The directory which stores the swiftly executable itself as well as symlinks
    /// to executables in the "bin" directory of the active toolchain.
    ///
    /// If a mocked home directory is set, this will be the "bin" subdirectory of the home directory.
    /// If not, this will be the SWIFTLY_BIN_DIR environment variable if set. If that's also unset,
    /// this will default to the platform's default location.
    func swiftlyBinDir(_ ctx: SwiftlyCoreContext) -> URL

    /// The "toolchains" subdirectory that contains the Swift toolchains managed by swiftly.
    func swiftlyToolchainsDir(_ ctx: SwiftlyCoreContext) -> URL

    /// The file extension of the downloaded toolchain for this platform.
    /// e.g. for Linux systems this is "tar.gz" and on macOS it's "pkg".
    var toolchainFileExtension: String { get }

    /// Installs a toolchain from a file on disk pointed to by the given URL.
    /// After this completes, a user can “use” the toolchain.
    func install(_ ctx: SwiftlyCoreContext, from: URL, version: ToolchainVersion, verbose: Bool)
        async throws

    /// Extract swiftly from the provided downloaded archive and install
    /// ourselves from that.
    func extractSwiftlyAndInstall(_ ctx: SwiftlyCoreContext, from archive: URL) async throws

    /// Uninstalls a toolchain associated with the given version.
    /// If this version is in use, the next latest version will be used afterwards.
    func uninstall(_ ctx: SwiftlyCoreContext, _ version: ToolchainVersion, verbose: Bool) async throws

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
    func verifySystemPrerequisitesForInstall(
        _ ctx: SwiftlyCoreContext, platformName: String, version: ToolchainVersion,
        requireSignatureValidation: Bool
    ) async throws -> String?

    /// Downloads the signature file associated with the archive and verifies it matches the downloaded archive.
    /// Throws an error if the signature does not match.
    func verifyToolchainSignature(
        _ ctx: SwiftlyCoreContext, toolchainFile: ToolchainFile, archive: URL, verbose: Bool
    )
        async throws

    /// Downloads the signature file associated with the archive and verifies it matches the downloaded archive.
    /// Throws an error if the signature does not match.
    func verifySwiftlySignature(
        _ ctx: SwiftlyCoreContext, archiveDownloadURL: URL, archive: URL, verbose: Bool
    ) async throws

    /// Detect the platform definition for this platform.
    func detectPlatform(_ ctx: SwiftlyCoreContext, disableConfirmation: Bool, platform: String?)
        async throws -> PlatformDefinition

    /// Get the user's current login shell
    func getShell() async throws -> String

    /// Find the location where the toolchain should be installed.
    func findToolchainLocation(_ ctx: SwiftlyCoreContext, _ toolchain: ToolchainVersion) -> URL

    /// Find the location of the toolchain binaries.
    func findToolchainBinDir(_ ctx: SwiftlyCoreContext, _ toolchain: ToolchainVersion) -> URL
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
    public func swiftlyHomeDir(_ ctx: SwiftlyCoreContext) -> URL {
        ctx.mockedHomeDir
            ?? ProcessInfo.processInfo.environment["SWIFTLY_HOME_DIR"].map { URL(fileURLWithPath: $0) }
            ?? self.defaultSwiftlyHomeDirectory
    }

    /// The URL of the configuration file in swiftly's home directory.
    public func swiftlyConfigFile(_ ctx: SwiftlyCoreContext) -> URL {
        self.swiftlyHomeDir(ctx).appendingPathComponent("config.json")
    }

#if os(macOS) || os(Linux)
    func proxyEnv(_ ctx: SwiftlyCoreContext, env: [String: String], toolchain: ToolchainVersion) throws -> [String: String] {
        var newEnv = env

        let tcPath = self.findToolchainLocation(ctx, toolchain).appendingPathComponent("usr/bin")
        guard tcPath.fileExists() else {
            throw SwiftlyError(
                message:
                "Toolchain \(toolchain) could not be located. You can try `swiftly uninstall \(toolchain)` to uninstall it and then `swiftly install \(toolchain)` to install it again."
            )
        }

        var pathComponents = (newEnv["PATH"] ?? "").split(separator: ":").map { String($0) }

        // The toolchain goes to the beginning of the PATH
        pathComponents.removeAll(where: { $0 == tcPath.path })
        pathComponents = [tcPath.path] + pathComponents

        // Remove swiftly bin directory from the PATH entirely
        let swiftlyBinDir = self.swiftlyBinDir(ctx)
        pathComponents.removeAll(where: { $0 == swiftlyBinDir.path })

        newEnv["PATH"] = String(pathComponents.joined(separator: ":"))

        return newEnv
    }

    /// Proxy the invocation of the provided command to the chosen toolchain.
    ///
    /// In the case where the command exit with a non-zero exit code a RunProgramError is thrown with
    /// the exit code and program information.
    ///
    public func proxy(_ ctx: SwiftlyCoreContext, _ toolchain: ToolchainVersion, _ command: String, _ arguments: [String], _ env: [String: String] = [:]) async throws {
        let tcPath = self.findToolchainLocation(ctx, toolchain).appendingPathComponent("usr/bin")

        let commandTcPath = tcPath.appendingPathComponent(command)
        let commandToRun = if FileManager.default.fileExists(atPath: commandTcPath.path) {
            commandTcPath.path
        } else {
            command
        }

        var newEnv = try self.proxyEnv(ctx, env: ProcessInfo.processInfo.environment, toolchain: toolchain)
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
        let tcPath = self.findToolchainLocation(ctx, toolchain).appendingPathComponent("usr/bin")

        let commandTcPath = tcPath.appendingPathComponent(command)
        let commandToRun = if FileManager.default.fileExists(atPath: commandTcPath.path) {
            commandTcPath.path
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
            throw RunProgramError(exitCode: process.terminationStatus, program: args.first!, arguments: Array(args.dropFirst()))
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
        let cmdAbsolute =
            if cmd.hasPrefix("/")
        {
            cmd
        } else {
            ([FileManager.default.currentDirectoryPath]
                + (ProcessInfo.processInfo.environment["PATH"]?.components(separatedBy: ":") ?? [])).map
                {
                    $0 + "/" + cmd
                }.filter {
                    FileManager.default.fileExists(atPath: $0)
                }.first
        }

        // We couldn't find ourselves in the usual places. Assume that no installation is necessary
        // since we were most likely invoked at SWIFTLY_BIN_DIR already.
        guard let cmdAbsolute else {
            return
        }

        // Proceed to installation only if we're in the user home directory, or a non-system location.
        let userHome = FileManager.default.homeDirectoryForCurrentUser
        guard
            cmdAbsolute.hasPrefix(userHome.path + "/")
            || (!cmdAbsolute.hasPrefix("/usr/") && !cmdAbsolute.hasPrefix("/opt/")
                && !cmdAbsolute.hasPrefix("/bin/"))
        else {
            return
        }

        // Proceed only if we're not running in the context of a mocked home directory.
        guard ctx.mockedHomeDir == nil else {
            return
        }

        // We're already running from where we would be installing ourselves.
        guard
            case let swiftlyHomeBin = self.swiftlyBinDir(ctx).appendingPathComponent(
                "swiftly", isDirectory: false
            ).path, cmdAbsolute != swiftlyHomeBin
        else {
            return
        }

        await ctx.print("Installing swiftly in \(swiftlyHomeBin)...")

        if FileManager.default.fileExists(atPath: swiftlyHomeBin) {
            try FileManager.default.removeItem(atPath: swiftlyHomeBin)
        }

        do {
            try FileManager.default.moveItem(atPath: cmdAbsolute, toPath: swiftlyHomeBin)
        } catch {
            try FileManager.default.copyItem(atPath: cmdAbsolute, toPath: swiftlyHomeBin)
            await ctx.print(
                "Swiftly has been copied into the installation directory. You can remove '\(cmdAbsolute)'. It is no longer needed."
            )
        }
    }

    // Find the location where swiftly should be executed.
    public func findSwiftlyBin(_ ctx: SwiftlyCoreContext) throws -> String? {
        let swiftlyHomeBin = self.swiftlyBinDir(ctx).appendingPathComponent(
            "swiftly", isDirectory: false
        ).path

        // First, let's find out where we are.
        let cmd = CommandLine.arguments[0]
        let cmdAbsolute =
            if cmd.hasPrefix("/")
        {
            cmd
        } else {
            ([FileManager.default.currentDirectoryPath]
                + (ProcessInfo.processInfo.environment["PATH"]?.components(separatedBy: ":") ?? [])).map
                {
                    $0 + "/" + cmd
                }.filter {
                    FileManager.default.fileExists(atPath: $0)
                }.first
        }

        // We couldn't find ourselves in the usual places, so if we're not going to be installing
        // swiftly then we can assume that we are running from the final location.
        if cmdAbsolute == nil && FileManager.default.fileExists(atPath: swiftlyHomeBin) {
            return swiftlyHomeBin
        }

        // If we are system managed then we know where swiftly should be.
        let userHome = FileManager.default.homeDirectoryForCurrentUser
        if let cmdAbsolute,
           !cmdAbsolute.hasPrefix(userHome.path + "/")
           && (cmdAbsolute.hasPrefix("/usr/") || cmdAbsolute.hasPrefix("/opt/")
               || cmdAbsolute.hasPrefix("/bin/"))
        {
            return cmdAbsolute
        }

        // If we're running inside an xctest then we don't have a location for this swiftly.
        guard let cmdAbsolute, !cmdAbsolute.hasSuffix("xctest") else {
            return nil
        }

        return FileManager.default.fileExists(atPath: swiftlyHomeBin) ? swiftlyHomeBin : nil
    }

    public func findToolchainBinDir(_ ctx: SwiftlyCoreContext, _ toolchain: ToolchainVersion) -> URL
    {
        self.findToolchainLocation(ctx, toolchain).appendingPathComponent("usr/bin")
    }

#endif
}
