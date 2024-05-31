import ArgumentParser
import SwiftlyCore
import Foundation

internal func runProgramOutput(_ program: String, _ args: String...) async throws -> String? {
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

internal struct Init: SwiftlyCommand {
    @Flag(name: [.customShort("n"), .long], help: "Do not attempt to modify the profile file to set environment variables (e.g. PATH) on login.")
    var noModifyProfile: Bool = false
    @Flag(name: .shortAndLong, help: """
        Overwrite the existing swiftly installation found at the configured SWIFTLY_HOME, if any. If this option is unspecified and an existing \
        installation is found, the swiftly executable will be updated, but the rest of the installation will not be modified.
        """)
    var overwrite: Bool = false
    @Option(name: .long, help: "Specify the current Linux platform for swiftly.")
    var platform: String?

    @OptionGroup var root: GlobalOptions

    internal mutating func run() async throws {
        try await Self.execute(assumeYes: root.assumeYes, noModifyProfile: noModifyProfile, overwrite: overwrite, platform: platform)
    }

    #if os(macOS)
    static func getShell() async throws -> String {
        if let shell = ProcessInfo.processInfo.environment["SHELL"] {
            return shell
        }

        if let directoryInfo = try await runProgramOutput("dscl", ".", "-read", FileManager.default.homeDirectoryForCurrentUser.path) {
            for line in directoryInfo.components(separatedBy: "\n") {
                if line.hasPrefix("UserShell: ") {
                    if case let comps = line.components(separatedBy: ": "), comps.count == 2 {
                        return comps[1]
                    }
                }
            }
        }

        // Fall back to zsh on macOS
        return "/bin/zsh"
    }
    #else
    static func getShell() async throws -> String {
        if let shell = ProcessInfo.processInfo.environment["SHELL"] {
            return shell
        }

        if let passwds = try await runProgramOutput("getent", "passwd") {
            for line in passwds.components(separatedBy: "\n") {
                if line.hasPrefix("root:") {
                    if case let comps = line.components(separatedBy: ":"), comps.count > 1 {
                        return comps[comps.count-1]
                    }
                }
            }
        }

        // Fall back on bash on Linux and other Unixes
        return "/bin/bash"
    }
    #endif

    /// Initialize the installation of swiftly.
    internal static func execute(assumeYes: Bool, noModifyProfile: Bool, overwrite: Bool, platform: String?) async throws {
        let shell = try await getShell()

        let envFile: URL
        let sourceLine: String
        if shell.hasSuffix("fish") {
            envFile = Swiftly.currentPlatform.swiftlyHomeDir.appendingPathComponent("env.fish", isDirectory: false)
            sourceLine = "\nsource \"\(envFile.path)\"\n"
        } else {
            envFile = Swiftly.currentPlatform.swiftlyHomeDir.appendingPathComponent("env.sh", isDirectory: false)
            sourceLine = "\n. \"\(envFile.path)\"\n"
        }

        // Give the user the prompt and the choice to abort at this point.
        if !assumeYes {
            SwiftlyCore.print("""
            Swiftly will be installed into the following locations:

            \(Swiftly.currentPlatform.swiftlyHomeDir.path) - Data and configuration files directory including toolchains
            \(Swiftly.currentPlatform.swiftlyBinDir.path) - Executables installation directory

            Note that the locations can be changed with SWIFTLY_HOME and SWIFTLY_BIN environment variables and run
            this again.

            Proceed with the installation?

            0) Cancel
            1) Install
            """)

            if SwiftlyCore.readLine(prompt: "> ") == "0" {
                throw Error(message: "Swiftly installation has been cancelled")
            }
        }

        if overwrite {
            try? FileManager.default.removeItem(at: Swiftly.currentPlatform.swiftlyToolchainsDir)
            try? FileManager.default.removeItem(at: Swiftly.currentPlatform.swiftlyHomeDir)
        }

        // Go ahead and create the directories as needed
        for requiredDir in Swiftly.requiredDirectories {
            if !requiredDir.fileExists() {
                do {
                    try FileManager.default.createDirectory(at: requiredDir, withIntermediateDirectories: true)
                } catch {
                    throw Error(message: "Failed to create required directory \"\(requiredDir.path)\": \(error)")
                }
            }
        }

        // Force the configuration to be present. Generate it if it doesn't already exist or overwrite is set
        let config = try? Config.load()
        if overwrite || config == nil {
            let pd = try await Swiftly.currentPlatform.detectPlatform(disableConfirmation: assumeYes, platform: platform)
            let config = Config(inUse: nil, installedToolchains: [], platform: pd)
            try config.save()
        }

        let swiftlyBin = Swiftly.currentPlatform.swiftlyBinDir.appendingPathComponent("swiftly", isDirectory: false)
        let swiftlyVer = if let reachable = try? swiftlyBin.checkResourceIsReachable(), reachable {
            if let version = try? await runProgramOutput(swiftlyBin.path, "--version") {
                try SwiftlyVersion(parsing: version.replacingOccurrences(of: "\n", with: ""))
            } else {
                SwiftlyVersion(major: 0, minor: 0, patch: 0)
            }
        } else {
            SwiftlyVersion(major: 0, minor: 0, patch: 0)
        }

        if !overwrite && swiftlyVer > version {
            throw Error(message: "Existing swiftly version \(swiftlyVer) is newer than this version to be installed \(version). If this is intended then try again with overwrite")
        }

        // Copy the swiftly binary
        SwiftlyCore.print("Copying swiftly into the installation directory...")

        let binLocs = [CommandLine.arguments[0]] + ProcessInfo.processInfo.environment["PATH"]!.components(separatedBy: ":").map( {$0 + "/" + CommandLine.arguments[0]} )
        var bin: String?
        for binLoc in binLocs {
            if FileManager.default.fileExists(atPath: binLoc) {
                bin = binLoc
                break
            }
        }

        guard let bin = bin else {
            throw Error(message: "Could not locate source of swiftly binary to copy into the installation location: \(CommandLine.arguments[0])")
        }

        try? FileManager.default.removeItem(at: swiftlyBin)
        try FileManager.default.copyItem(at: URL(fileURLWithPath: bin), to: swiftlyBin)

        // TODO consider whether symlinks are the right answer for all platforms (e.g. Windows)
        // (Re)create the symlinks for the proxies if they aren't there or overwrite is specified
        for proxy in proxyList {
            let bin = Swiftly.currentPlatform.swiftlyBinDir.appendingPathComponent(proxy, isDirectory: false)
            let exists = FileManager.default.fileExists(atPath: bin.path)

            if overwrite || !exists {
                try bin.deleteIfExists()

                try FileManager.default.createSymbolicLink(
                    atPath: bin.path,
                    withDestinationPath: "swiftly"
                )
            }
        }

        if !FileManager.default.fileExists(atPath: envFile.path) {
            SwiftlyCore.print("Creating shell environment file for the user...")
            var env = ""
            if shell.hasSuffix("fish") {
                env = """
                set -x SWIFTLY_HOME_DIR "\(Swiftly.currentPlatform.swiftlyHomeDir.path)"
                set -x SWIFTLY_BIN_DIR "\(Swiftly.currentPlatform.swiftlyBinDir.path)"
                if not contains "$SWIFTLY_BIN_DIR" $PATH
                    set -x PATH "$SWIFTLY_BIN_DIR" $PATH
                end

                """
            } else {
                env = """
                export SWIFTLY_HOME_DIR="\(Swiftly.currentPlatform.swiftlyHomeDir.path)"
                export SWIFTLY_BIN_DIR="\(Swiftly.currentPlatform.swiftlyBinDir.path)"
                if [[ ":$PATH:" != *":$SWIFTLY_BIN_DIR:"* ]]; then
                    export PATH="$SWIFTLY_BIN_DIR:$PATH"
                fi

                """
            }

            try Data(env.utf8).write(to: envFile, options: .atomic)
        }

        if !noModifyProfile && !ProcessInfo.processInfo.environment["PATH"]!.contains(Swiftly.currentPlatform.swiftlyBinDir.path) {
            SwiftlyCore.print("Updating profile...")

            guard let homeVar = ProcessInfo.processInfo.environment["HOME"], case let userHome = URL(fileURLWithPath: homeVar) else {
                fatalError("User's HOME is not set")
            }

            let profileHome: URL
            if shell.hasSuffix("zsh") {
                profileHome = userHome.appendingPathComponent(".zprofile", isDirectory: false)
            } else if shell.hasSuffix("bash") {
                if case let p = userHome.appendingPathComponent(".bash_profile", isDirectory: false), FileManager.default.fileExists(atPath: p.path) {
                    profileHome = p
                } else if case let p = userHome.appendingPathComponent(".bash_login", isDirectory: false), FileManager.default.fileExists(atPath: p.path) {
                    profileHome = p
                } else {
                    profileHome = userHome.appendingPathComponent(".profile", isDirectory: false)
                }
            } else if shell.hasSuffix("fish") {
                if let xdgConfigHome = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"], case let xdgConfigURL = URL(fileURLWithPath: xdgConfigHome) {
                    let confDir = xdgConfigURL.appendingPathComponent("fish/conf.d", isDirectory: true)
                    try FileManager.default.createDirectory(at: confDir, withIntermediateDirectories: true)
                    profileHome = confDir.appendingPathComponent("swiftly.fish", isDirectory: false)
                } else {
                    let confDir = userHome.appendingPathComponent(".config/fish/conf.d", isDirectory: true)
                    try FileManager.default.createDirectory(at: confDir, withIntermediateDirectories: true)
                    profileHome = confDir.appendingPathComponent("swiftly.fish", isDirectory: false)
                }
            } else {
                profileHome = userHome.appendingPathComponent(".profile", isDirectory: false)
            }

            var addEnvToProfile = false
            do {
                if !FileManager.default.fileExists(atPath: profileHome.path) {
                    addEnvToProfile = true
                } else if case let profileContents = try String(contentsOf: profileHome), !profileContents.contains(sourceLine) {
                    addEnvToProfile = true
                }
            } catch {
                addEnvToProfile = true
            }

            if addEnvToProfile {
                try Data(sourceLine.utf8).append(file: profileHome)

                SwiftlyCore.print("""
                To begin using installed swiftly from your current shell, first run the following command:
                    \(sourceLine)
                """)

                #if os(macOS)
                SwiftlyCore.print("""
                    NOTE: On macOS it is possible that the shell will pick up the system Swift on the path
                    instead of the one that swiftly has installed for you. You can run the 'hash -r'
                    command to update the shell with the latest PATHs.

                        hash -r
                    """
                )
                #endif
            }
        }
    }
}
