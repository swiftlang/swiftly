import ArgumentParser
import Foundation
#if os(Linux)
import LinuxPlatform
#elseif os(macOS)
import MacOSPlatform
#endif
import SwiftlyCore

public struct GlobalOptions: ParsableArguments {
    @Flag(name: [.customShort("y"), .long], help: "Disable confirmation prompts by assuming 'yes'")
    var assumeYes: Bool = false
    @Flag(name: [.customShort("n"), .long], help: "Do not attempt to modify the profile file to set environment variables (e.g. PATH) on login.")
    var noModifyProfile: Bool = false
    @Flag(name: .shortAndLong, help: "Overwrite the existing swiftly installation found at the configured SWIFTLY_HOME, if any. If this option is unspecified and an existing installation is found, the swiftly executable will be updated, but the rest of the installation will not be modified.")
    var overwrite: Bool = false
    @Option(name: .long, help: "Specify the current Linux platform for swiftly.")
    var platform: String?

    public init() {}
}

@main
public struct Swiftly: SwiftlyCommand {
    public static var configuration = CommandConfiguration(
        abstract: "A utility for installing and managing Swift toolchains.",

        version: String(describing: SwiftlyCore.version),

        subcommands: [
            Install.self,
            Use.self,
            Uninstall.self,
            List.self,
            Update.self,
            SelfUpdate.self,
        ]
    )

    /// The list of directories that swiftly needs to exist in order to execute.
    /// If they do not exist when a swiftly command is invoked, they will be created.
    public static var requiredDirectories: [URL] {
        [
            Swiftly.currentPlatform.swiftlyHomeDir,
            Swiftly.currentPlatform.swiftlyBinDir,
            Swiftly.currentPlatform.swiftlyToolchainsDir,
        ]
    }

    @OptionGroup var root: GlobalOptions

    public init() {}

#if os(Linux)
    internal static let currentPlatform = Linux.currentPlatform
#elseif os(macOS)
    internal static let currentPlatform = MacOS.currentPlatform
#endif
}

public protocol SwiftlyCommand: AsyncParsableCommand {}

extension Data {
    func append(file: URL) throws {
        if let fileHandle = FileHandle(forWritingAtPath: file.path) {
            defer {
                fileHandle.closeFile()
            }
            fileHandle.seekToEndOfFile()
            fileHandle.write(self)
        } else {
            try write(to: file, options: .atomic)
        }
    }
}

internal func runProgramOutput(_ args: String...) async throws -> String? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = args

    let outPipe = Pipe()
    process.standardInput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    process.standardOutput = outPipe

    try process.run()

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

extension SwiftlyCommand {
    #if os(macOS)
    internal func getShell() async throws -> String {
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
    internal func getShell() async throws -> String {
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

    public mutating func validate(_ root: GlobalOptions) async throws -> Config {
        // Check if the system has CA certificate trust installed so that swiftly
        //  can use trusted TLS for its http requests.
        if !Swiftly.currentPlatform.isSystemDependencyPresent(.caCertificates) {
            throw Error(message: "CA certificate trust is not available")
        }

        let assumeYes = root.assumeYes
        let noModifyProfile = root.noModifyProfile
        let overwrite = root.overwrite

        // Let's check to see if swiftly is installed, or this is the first time
        //  it has been run. This includes the required directories, the swift binary
        //  and potentially whether the PATH has been updated.
        var installed = Swiftly.requiredDirectories.allSatisfy { $0.fileExists() }

        if case let swiftlyBin = Swiftly.currentPlatform.swiftlyBinDir.appendingPathComponent("swiftly", isDirectory: false), !FileManager.default.fileExists(atPath: swiftlyBin.path)  {
            installed = false
        }

        let shell = try await getShell()

        let envFile: URL
        if shell.hasSuffix("fish") {
            envFile = Swiftly.currentPlatform.swiftlyHomeDir.appendingPathComponent("env.fish", isDirectory: false)
        } else {
            envFile = Swiftly.currentPlatform.swiftlyHomeDir.appendingPathComponent("env.sh", isDirectory: false)
        }

        let sourceLine = "\n. \(envFile.path)\n"

        if !FileManager.default.fileExists(atPath: envFile.path) {
            installed = false
        }

        if installed && FileManager.default.fileExists(atPath: envFile.path) && !ProcessInfo.processInfo.environment["PATH"]!.contains(Swiftly.currentPlatform.swiftlyBinDir.path) {
            // The user doesn't seem to have updated their shell since installation.
            //  Let's offer some help.
            SwiftlyCore.print("""
            To use the installed swiftly from shell you can run the following command:
                \(sourceLine)
            """)
        }

        // Give the user the prompt and the choice to abort to abort at this point.
        if !assumeYes && !installed {
            SwiftlyCore.print("""
            Swiftly can be installed into the following locations:

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

        // Force the configuration to be present. Generate it if it doesn't already exist
        let config = try await Config.load(options: root)
        if overwrite {
            try config.save()
        }

        // Copy the swiftly binary if it isn't there or overwrite is specified
        // CommandLine.arguments
        if case let swiftlyBin = Swiftly.currentPlatform.swiftlyBinDir.appendingPathComponent("swiftly", isDirectory: false), !FileManager.default.fileExists(atPath: swiftlyBin.path) || overwrite  {
            SwiftlyCore.print("Copying swiftly into the installation directory...")
            try? FileManager.default.removeItem(at: swiftlyBin)
            try FileManager.default.copyItem(at: URL(fileURLWithPath: CommandLine.arguments[0]), to: swiftlyBin)
        }

        // If everything is installed then we can leave at this point
        if installed && !overwrite {
            return config
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
                export SWIFTLY_BIN_DIR=""\(Swiftly.currentPlatform.swiftlyBinDir.path)
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
            }
        }

        return config
    }
}
