import ArgumentParser
import Foundation
import Subprocess
import SwiftlyCore
import SystemPackage

#if os(macOS)
import System
#endif

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

        guard case let swiftlyArchive = SystemPackage.FilePath(swiftlyArchive) else { fatalError("") }

        print("Extracting swiftly release")
#if os(Linux)
        try await sys.tar().extract(.verbose, .compressed, .archive(swiftlyArchive)).run(quiet: false)
#elseif os(macOS)
        try await sys.installer(.verbose, .pkg(swiftlyArchive), .target("CurrentUserHomeDirectory")).run(quiet: false)
#endif

#if os(Linux)
        let extractedSwiftly = SystemPackage.FilePath("./swiftly")
#elseif os(macOS)
        let extractedSwiftly = System.FilePath((fs.home / ".swiftly/bin/swiftly").string)
#endif

        var env: Environment = .inherit
        let shell = SystemPackage.FilePath(try await currentPlatform.getShell())
        var customLoc: SystemPackage.FilePath?

        if self.customLocation {
            customLoc = fs.mktemp()

            print("Installing swiftly to custom location \(customLoc!)")

            env = env.updating([
                "SWIFTLY_HOME_DIR": customLoc!.string,
                "SWIFTLY_BIN_DIR": (customLoc! / "bin").string,
                "SWIFTLY_TOOLCHAINS_DIR": (customLoc! / "toolchains").string,
            ])

            _ = try await Subprocess.run(.path(extractedSwiftly), arguments: ["init", "--assume-yes", "--no-modify-profile", "--skip-install"], environment: env, input: .standardInput, output: .standardOutput, error: .standardError)
            _ = try await sh(executable: .path(shell), .login, .command(". \"\(customLoc! / "env.sh")\" && swiftly install --assume-yes latest --post-install-file=./post-install.sh")).run(environment: env, output: .standardOutput, error: .standardError)
        } else {
            print("Installing swiftly to the default location.")
            // Setting this environment helps to ensure that the profile gets sourced with bash, even if it is not in an interactive shell
            if shell.ends(with: "bash") {
                env = env.updating(["BASH_ENV": (fs.home / ".profile").string])
            } else if shell.ends(with: "zsh") {
                env = env.updating(["ZDOTDIR": fs.home.string])
            } else if shell.ends(with: "fish") {
                env = env.updating(["XDG_CONFIG_HOME": (fs.home / ".config").string])
            }

            _ = try await Subprocess.run(.path(extractedSwiftly), arguments: ["init", "--assume-yes", "--skip-install"], environment: env, input: .standardInput, output: .standardOutput, error: .standardError)
            _ = try await sh(executable: .path(shell), .login, .command("swiftly install --assume-yes latest --post-install-file=./post-install.sh")).run(environment: env, output: .standardOutput, error: .standardError)
        }

        var swiftReady = false

        if NSUserName() == "root" {
            if try await fs.exists(atPath: "./post-install.sh") {
                _ = try await Subprocess.run(.path(shell), arguments: ["./post-install.sh"], input: .standardInput, output: .standardOutput, error: .standardError)
            }
            swiftReady = true
        } else if try await fs.exists(atPath: "./post-install.sh") {
            print("WARNING: not running as root, so skipping the post installation steps and final swift verification.")
        } else {
            swiftReady = true
        }

        if let customLoc = customLoc, swiftReady {
            _ = try await sh(executable: .path(shell), .login, .command(". \"\(customLoc / "env.sh")\" && swift --version")).run(environment: env, output: .standardOutput, error: .standardError)
        } else if swiftReady {
            _ = try await sh(executable: .path(shell), .login, .command("swift --version")).run(environment: env, output: .standardOutput, error: .standardError)
        }

        // Test self-uninstall functionality
        print("Testing self-uninstall functionality")
        try await self.testSelfUninstall(customLoc: customLoc, shell: shell, env: env)
    }

    private func testSelfUninstall(customLoc: SystemPackage.FilePath?, shell: SystemPackage.FilePath, env: Environment) async throws {
        if let customLoc = customLoc {
            // Test self-uninstall for custom location
            _ = try await sh(executable: .path(shell), .login, .command(". \"\(customLoc / "env.sh")\" && swiftly self-uninstall --assume-yes")).run(environment: env, output: .standardOutput, error: .standardError)

            // Verify cleanup for custom location
            try await self.verifyCustomLocationCleanup(customLoc: customLoc)
        } else {
            // Test self-uninstall for default location
            _ = try await sh(executable: .path(shell), .login, .command("swiftly self-uninstall --assume-yes")).run(environment: env, output: .standardOutput, error: .standardError)

            // Verify cleanup for default location
            try await self.verifyDefaultLocationCleanup(shell: shell, env: env)
        }
    }

    private func verifyCustomLocationCleanup(customLoc: SystemPackage.FilePath) async throws {
        print("Verifying cleanup for custom location at \(customLoc)")

        // Check that swiftly binary is removed
        let swiftlyBinary = customLoc / "bin/swiftly"
        guard !(try await fs.exists(atPath: swiftlyBinary)) else {
            throw TestError("Swiftly binary still exists at \(swiftlyBinary)")
        }

        // Check that env files are removed
        let envSh = customLoc / "env.sh"
        let envFish = customLoc / "env.fish"
        guard !(try await fs.exists(atPath: envSh)) else {
            throw TestError("env.sh still exists at \(envSh)")
        }
        guard !(try await fs.exists(atPath: envFish)) else {
            throw TestError("env.fish still exists at \(envFish)")
        }

        // Check that config is removed
        let config = customLoc / "config.json"
        guard !(try await fs.exists(atPath: config)) else {
            throw TestError("config.json still exists at \(config)")
        }

        print("✓ Custom location cleanup verification passed")
    }

    private func verifyDefaultLocationCleanup(shell: SystemPackage.FilePath, env: Environment) async throws {
        print("Verifying cleanup for default location")

        let swiftlyHome = fs.home / ".swiftly"
        let swiftlyBin = swiftlyHome / "bin"

        // Check that swiftly binary is removed
        let swiftlyBinary = swiftlyBin / "swiftly"
        guard !(try await fs.exists(atPath: swiftlyBinary)) else {
            throw TestError("Swiftly binary still exists at \(swiftlyBinary)")
        }

        // Check that env files are removed
        let envSh = swiftlyHome / "env.sh"
        let envFish = swiftlyHome / "env.fish"
        guard !(try await fs.exists(atPath: envSh)) else {
            throw TestError("env.sh still exists at \(envSh)")
        }
        guard !(try await fs.exists(atPath: envFish)) else {
            throw TestError("env.fish still exists at \(envFish)")
        }

        // Check that config is removed
        let config = swiftlyHome / "config.json"
        guard !(try await fs.exists(atPath: config)) else {
            throw TestError("config.json still exists at \(config)")
        }

        // Check that shell profile files have been cleaned up
        try await self.verifyProfileCleanup()

        // Verify swiftly command is no longer available
        do {
            _ = try await sh(executable: .path(shell), .login, .command("which swiftly")).run(environment: env, output: .standardOutput, error: .standardError)
            throw TestError("swiftly command is still available in PATH after uninstall")
        } catch {
            // Expected - swiftly should not be found
        }

        print("✓ Default location cleanup verification passed")
    }

    private func verifyProfileCleanup() async throws {
        print("Verifying shell profile cleanup")

        let profilePaths: [SystemPackage.FilePath] = [
            fs.home / ".zprofile",
            fs.home / ".bash_profile",
            fs.home / ".bash_login",
            fs.home / ".profile",
            fs.home / ".config/fish/conf.d/swiftly.fish",
        ]

        let swiftlySourcePattern = ". \".*\\.swiftly/env\\.sh\""
        let fishSourcePattern = "source \".*\\.swiftly/env\\.fish\""
        let commentPattern = "# Added by swiftly"

        for profilePath in profilePaths {
            guard try await fs.exists(atPath: profilePath) else { continue }

            let contents = try String(contentsOf: profilePath, encoding: .utf8)

            // Check that swiftly-related lines are removed
            if contents.range(of: swiftlySourcePattern, options: .regularExpression) != nil ||
                contents.range(of: fishSourcePattern, options: .regularExpression) != nil ||
                contents.contains(commentPattern)
            {
                throw TestError("Swiftly references still found in profile file: \(profilePath)")
            }
        }

        print("✓ Shell profile cleanup verification passed")
    }
}

struct TestError: Error {
    let message: String

    init(_ message: String) {
        self.message = message
    }
}
