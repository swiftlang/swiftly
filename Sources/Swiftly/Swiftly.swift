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

    public init() {}
}

private func findSwiftVersionFromFile() -> String? {
    var cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

    while true {
        guard FileManager.default.fileExists(atPath: cwd.path) else {
            break
        }

        let svFile = cwd.appendingPathComponent(".swift-version", isDirectory: false)

        if FileManager.default.fileExists(atPath: svFile.path) {
            do {
                let contents = try String(contentsOf: svFile, encoding: .utf8)
                if !contents.isEmpty {
                    return contents.replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: "\r", with: "")
                }
            } catch {}
        }

        cwd = cwd.deletingLastPathComponent()
    }

    return nil
}

private func findInstalledToolchain(_ config: Config, _ selection: String) async throws -> ToolchainVersion {
    let selector = try ToolchainSelector(parsing: selection)

    if let matched = config.listInstalledToolchains(selector: selector).max() {
        return matched
    } else {
        // Run ourselves to try and install the selected toolchain
        let process = Process()
        process.executableURL = Swiftly.currentPlatform.swiftlyBinDir.appendingPathComponent("swiftly", isDirectory: false)
        process.arguments = ["install", selection]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.standardError
        process.standardError = FileHandle.standardError

        try process.run()
        // Attach this process to our process group so that Ctrl-C and other signals work
        let pgid = tcgetpgrp(STDOUT_FILENO)
        if pgid != -1 {
            tcsetpgrp(STDOUT_FILENO, process.processIdentifier)
        }
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            exit(process.terminationStatus)
        }

        let config = try Config.load()

        guard let matched = config.listInstalledToolchains(selector: selector).max() else {
            throw Error(message: "Unable to install selected toolchain: \(selector)")
        }

        return matched
    }
}

let proxyList = ["clang", "lldb", "lldb-dap", "lldb-server", "clang++", "sourcekit-lsp", "clangd",
                 "swift", "docc", "swiftc", "lld", "llvm-ar", "plutil", "repl_swift", "wasm-ld"]

// This is the main entry point for the proxy.
@main
public struct Proxy {
    static func main() async throws {
        do {
            let zero = CommandLine.arguments[0]
            guard let binName = zero.components(separatedBy: "/").last else {
                fatalError("Could not determine the binary name for proxying")
            }

            guard proxyList.contains(binName) else {
                // Treat this as a swiftly invocation

                // Special case of swiftly-init that bootstraps the installation process
                //  and just folds into the init subcommand. Note that the binary name can
                //  get appended by a web browser download with "-1", or "(1)" and so on
                //  so this is a prefix check.
                if binName.hasPrefix("swiftly-init") {
                    await Init.main()
                    exit(0)
                }

                await Swiftly.main()
                return
            }

            let config = try Config.load()
            let proxyArgs = CommandLine.arguments.filter( { $0.hasPrefix("+") } ).map( { String($0.dropFirst(1)) } )
            let toolchain: ToolchainVersion

            if proxyArgs.count > 0 {
                guard proxyArgs.count == 1 else {
                    throw Error(message: "More than one toolchain selector specified")
                }

                toolchain = try await findInstalledToolchain(config, proxyArgs[0])
            } else if let swiftVersion = findSwiftVersionFromFile() {
                toolchain = try await findInstalledToolchain(config, swiftVersion)
            } else if let inUse = config.inUse {
                toolchain = inUse
            } else {
                throw Error(message: "No toolchain could be determined either through a toolchain selector (e.g. +5.7.2, +latest), or one that is in use.")
            }
            try await Swiftly.currentPlatform.proxy(toolchain, binName, CommandLine.arguments[1...].filter( { !$0.hasPrefix("+") }))
        } catch {
            SwiftlyCore.print("\(error)")
            exit(1)
        }
    }
}


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
            Init.self,
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

extension SwiftlyCommand {
    public mutating func validate(_ root: GlobalOptions) async throws -> Config {
        // Check if the system has CA certificate trust installed so that swiftly
        //  can use trusted TLS for its http requests.
        if !Swiftly.currentPlatform.isSystemDependencyPresent(.caCertificates) {
            throw Error(message: "CA certificate trust is not available")
        }

        // Let's check to see if swiftly is installed, or this is the first time
        //  it has been run. This includes the required directories, the swift binary
        //  and potentially whether the PATH has been updated.
        var installed = Swiftly.requiredDirectories.allSatisfy { $0.fileExists() }

        if case let swiftlyBin = Swiftly.currentPlatform.swiftlyBinDir.appendingPathComponent("swiftly", isDirectory: false),
           !FileManager.default.fileExists(atPath: swiftlyBin.path) {
            installed = false
        }

        if !proxyList.allSatisfy({ proxy in
            let bin = Swiftly.currentPlatform.swiftlyBinDir.appendingPathComponent(proxy, isDirectory: false)
            return FileManager.default.fileExists(atPath: bin.path)
        }) {
            installed = false
        }

        let shell = try await Init.getShell()

        let envFile: URL
        if shell.hasSuffix("fish") {
            envFile = Swiftly.currentPlatform.swiftlyHomeDir.appendingPathComponent("env.fish", isDirectory: false)
        } else {
            envFile = Swiftly.currentPlatform.swiftlyHomeDir.appendingPathComponent("env.sh", isDirectory: false)
        }

        let sourceLine = "\n. \"\(envFile.path)\"\n"

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

        if !FileManager.default.fileExists(atPath: Swiftly.currentPlatform.swiftlyHomeDir.appendingPathComponent("config.json", isDirectory: false).path) {
            installed = false
        }

        if !proxyList.allSatisfy({ proxy in
            let bin = Swiftly.currentPlatform.swiftlyBinDir.appendingPathComponent(proxy, isDirectory: false)
            return FileManager.default.fileExists(atPath: bin.path)
        }) {
            installed = false
        }

        guard installed else {
            throw Error(message: "swiftly is not installed. Please run 'swiftly init' or 'swiftly-init' to install it.")
        }

        let config = try Config.load()
        return config
    }
}
