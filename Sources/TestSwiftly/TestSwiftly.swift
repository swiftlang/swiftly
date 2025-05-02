import ArgumentParser
import Foundation
import SwiftlyCore
import SystemPackage

#if os(Linux)
import LinuxPlatform
#elseif os(macOS)
import MacOSPlatform
#endif

#if os(Linux)
let currentPlatform: Platform = Linux.currentPlatform
#elseif os(macOS)
let currentPlatform: Platform = MacOS.currentPlatform
#else
#error("Unsupported platform")
#endif

typealias sys = SwiftlyCore.SystemCommand
typealias fs = SwiftlyCore.FileSystem

func sh(executable: Executable = ShCommand.defaultExecutable, _ options: ShCommand.Option...) -> ShCommand {
    sh(executable: executable, options)
}

func sh(executable: Executable = ShCommand.defaultExecutable, _ options: [ShCommand.Option]) -> ShCommand {
    ShCommand(executable: executable, options)
}

struct ShCommand {
    static var defaultExecutable: Executable { .name("sh") }

    var executable: Executable

    var options: [Option]

    enum Option {
        case login
        case command(String)

        func args() -> [String] {
            switch self {
            case .login:
                ["-l"]
            case let .command(command):
                ["-c", command]
            }
        }
    }

    init(executable: Executable, _ options: [Option]) {
        self.executable = executable
        self.options = options
    }

    func config() -> Configuration {
        var args: [String] = []

        for opt in self.options {
            args.append(contentsOf: opt.args())
        }

        return Configuration(
            executable: self.executable,
            arguments: Arguments(args),
            environment: .inherit
        )
    }
}

extension ShCommand: Runnable {}

@main
struct TestSwiftly: AsyncParsableCommand {
    @Flag(name: [.customShort("y"), .long], help: "Disable confirmation prompts by assuming 'yes'")
    var assumeYes: Bool = false

    @Flag(help: "Install swiftly to a custom location, not added to the user profile.")
    var customLocation: Bool = false

    @Argument var swiftlyArchive: String? = nil

    mutating func run() async throws {
        if !self.assumeYes {
            print("WARNING: This test will mutate your system to test the swiftly installation end-to-end. Please run this on a fresh system and try again with '--assume-yes'.")
            Foundation.exit(2)
        }

        guard let swiftlyArchive = self.swiftlyArchive else {
            print("ERROR: You must provide a swiftly archive path for the test.")
            Foundation.exit(2)
        }

        guard case let swiftlyArchive = FilePath(swiftlyArchive) else { fatalError("") }

        print("Extracting swiftly release")
#if os(Linux)
        try await sys.tar().extract(.verbose, .compressed, .file(swiftlyArchive)).run(currentPlatform, quiet: false)
#elseif os(macOS)
        try await sys.installer(.verbose, pkg: swiftlyArchive, target: "CurrentUserHomeDirectory").run(currentPlatform, quiet: false)
#endif

#if os(Linux)
        let extractedSwiftly = FilePath("./swiftly")
#elseif os(macOS)
        let extractedSwiftly = fs.home / ".swiftly/bin/swiftly"
#endif

        var env = ProcessInfo.processInfo.environment
        let shell = FilePath(try await currentPlatform.getShell())
        var customLoc: FilePath?

        if self.customLocation {
            customLoc = fs.mktemp()

            print("Installing swiftly to custom location \(customLoc!)")
            env["SWIFTLY_HOME_DIR"] = customLoc!.string
            env["SWIFTLY_BIN_DIR"] = (customLoc! / "bin").string
            env["SWIFTLY_TOOLCHAINS_DIR"] = (customLoc! / "toolchains").string

            try currentPlatform.runProgram(extractedSwiftly.string, "init", "--assume-yes", "--no-modify-profile", "--skip-install", quiet: false, env: env)
            try await sh(executable: .path(shell), .login, .command(". \"\(customLoc! / "env.sh")\" && swiftly install --assume-yes latest --post-install-file=./post-install.sh")).run(currentPlatform, env: env, quiet: false)
        } else {
            print("Installing swiftly to the default location.")
            // Setting this environment helps to ensure that the profile gets sourced with bash, even if it is not in an interactive shell
            if shell.ends(with: "bash") {
                env["BASH_ENV"] = (fs.home / ".profile").string
            } else if shell.ends(with: "zsh") {
                env["ZDOTDIR"] = fs.home.string
            } else if shell.ends(with: "fish") {
                env["XDG_CONFIG_HOME"] = (fs.home / ".config").string
            }

            try currentPlatform.runProgram(extractedSwiftly.string, "init", "--assume-yes", "--skip-install", quiet: false, env: env)
            try await sh(executable: .path(shell), .login, .command("swiftly install --assume-yes latest --post-install-file=./post-install.sh")).run(currentPlatform, env: env, quiet: false)
        }

        var swiftReady = false

        if NSUserName() == "root" {
            if try await fs.exists(atPath: "./post-install.sh") {
                try currentPlatform.runProgram(shell.string, "./post-install.sh", quiet: false)
            }
            swiftReady = true
        } else if try await fs.exists(atPath: "./post-install.sh") {
            print("WARNING: not running as root, so skipping the post installation steps and final swift verification.")
        } else {
            swiftReady = true
        }

        if let customLoc = customLoc, swiftReady {
            try await sh(executable: .path(shell), .login, .command(". \"\(customLoc / "env.sh")\" && swift --version")).run(currentPlatform, env: env, quiet: false)
        } else if swiftReady {
            try await sh(executable: .path(shell), .login, .command("swift --version")).run(currentPlatform, env: env, quiet: false)
        }
    }
}
