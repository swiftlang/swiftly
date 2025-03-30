import ArgumentParser
import Foundation
import SwiftlyCore

struct Init: SwiftlyCommand {
    public static var configuration = CommandConfiguration(
        abstract: "Perform swiftly initialization into your user account."
    )

    @Flag(name: [.customShort("n"), .long], help: "Do not attempt to modify the profile file to set environment variables (e.g. PATH) on login.")
    var noModifyProfile: Bool = false
    @Flag(name: .shortAndLong, help: """
    Overwrite the existing swiftly installation found at the configured SWIFTLY_HOME, if any. If this option is unspecified and an existing \
    installation is found, the swiftly executable will be updated, but the rest of the installation will not be modified.
    """)
    var overwrite: Bool = false
    @Option(name: .long, help: "Specify the current Linux platform for swiftly")
    var platform: String?
    @Flag(help: "Skip installing the latest toolchain")
    var skipInstall: Bool = false
    @Flag(help: "Quiet shell follow up commands")
    var quietShellFollowup: Bool = false

    @OptionGroup var root: GlobalOptions

    private enum CodingKeys: String, CodingKey {
        case noModifyProfile, overwrite, platform, skipInstall, root, quietShellFollowup
    }

    public mutating func validate() throws {}

    mutating func run() async throws {
        try await Self.execute(assumeYes: self.root.assumeYes, noModifyProfile: self.noModifyProfile, overwrite: self.overwrite, platform: self.platform, verbose: self.root.verbose, skipInstall: self.skipInstall, quietShellFollowup: self.quietShellFollowup)
    }

    /// Initialize the installation of swiftly.
    static func execute(assumeYes: Bool, noModifyProfile: Bool, overwrite: Bool, platform: String?, verbose: Bool, skipInstall: Bool, quietShellFollowup: Bool) async throws {
        try Swiftly.currentPlatform.verifySwiftlySystemPrerequisites()

        var config = try? Config.load()

        if var config, !overwrite &&
            (
                config.version == SwiftlyVersion(major: 0, minor: 4, patch: 0, suffix: "dev") ||
                    config.version == SwiftlyVersion(major: 0, minor: 4, patch: 0) ||
                    (config.version?.major == 1 && config.version?.minor == 0)
            )
        {
            // This is a simple upgrade from the 0.4.0 pre-releases, or 1.x

            // Move our executable over to the correct place
            try Swiftly.currentPlatform.installSwiftlyBin()

            // Update and save the version
            config.version = SwiftlyCore.version

            try config.save()

            return
        }

        if let config, !overwrite && config.version != SwiftlyCore.version {
            // We don't support downgrades, and versions prior to 0.4.0-dev
            throw SwiftlyError(message: "An existing swiftly installation was detected. You can try again with '--overwrite' to overwrite it.")
        }

        // Give the user the prompt and the choice to abort at this point.
        if !assumeYes {
            var msg = """
                Welcome to swiftly, the Swift toolchain manager for Linux and macOS!

                Please read the following information carefully before proceeding with the installation. If you
                wish to customize the steps performed during the installation process, refer to 'swiftly init -h'
                for configuration options.

                Swiftly installs files into the following locations:

                \(Swiftly.currentPlatform.swiftlyHomeDir.path) - Directory for configuration files
                \(Swiftly.currentPlatform.swiftlyBinDir.path) - Links to the binaries of the active toolchain
                \(Swiftly.currentPlatform.swiftlyToolchainsDir.path) - Directory hosting installed toolchains

                These locations can be changed by setting the environment variables
                SWIFTLY_HOME_DIR and SWIFTLY_BIN_DIR before running 'swiftly init' again.

                """
            if !skipInstall {
                msg += """

                    Once swiftly is set up, it will install the latest available Swift toolchain.

                    """
                #if os(Linux)
                msg += """
                    In the process, swiftly will add swift.org GnuPG keys into your keychain to verify
                    the integrity of the downloads.

                    """
                #endif
            }

            SwiftlyCore.print(msg)

            guard SwiftlyCore.promptForConfirmation(defaultBehavior: true) else {
                throw SwiftlyError(message: "swiftly installation has been cancelled")
            }
        }

        let shell = if let s = ProcessInfo.processInfo.environment["SHELL"] {
            s
        } else {
            try await Swiftly.currentPlatform.getShell()
        }

        let envFile: URL
        let sourceLine: String
        if shell.hasSuffix("fish") {
            envFile = Swiftly.currentPlatform.swiftlyHomeDir.appendingPathComponent("env.fish", isDirectory: false)
            sourceLine = """

            # Added by swiftly
            source "\(envFile.path)"
            """
        } else {
            envFile = Swiftly.currentPlatform.swiftlyHomeDir.appendingPathComponent("env.sh", isDirectory: false)
            sourceLine = """

            # Added by swiftly
            . "\(envFile.path)"
            """
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
                    throw SwiftlyError(message: "Failed to create required directory \"\(requiredDir.path)\": \(error)")
                }
            }
        }

        // Force the configuration to be present. Generate it if it doesn't already exist or overwrite is set
        if overwrite || config == nil {
            let pd = try await Swiftly.currentPlatform.detectPlatform(disableConfirmation: assumeYes, platform: platform)
            var c = Config(inUse: nil, installedToolchains: [], platform: pd)
            // Stamp the current version of swiftly on this config
            c.version = SwiftlyCore.version
            try c.save()
            config = c
        }

        guard var config else { throw SwiftlyError(message: "Configuration could not be set") }

        // Move our executable over to the correct place
        try Swiftly.currentPlatform.installSwiftlyBin()

        if overwrite || !FileManager.default.fileExists(atPath: envFile.path) {
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

        if !noModifyProfile {
            SwiftlyCore.print("Updating profile...")

            let userHome = FileManager.default.homeDirectoryForCurrentUser

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
                    let confDir = userHome.appendingPathComponent(
                        ".config/fish/conf.d", isDirectory: true
                    )
                    try FileManager.default.createDirectory(
                        at: confDir, withIntermediateDirectories: true
                    )
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

            var postInstall: String?
            var pathChanged = false

            if !skipInstall {
                let latestVersion = try await Install.resolve(config: config, selector: ToolchainSelector.latest)
                (postInstall, pathChanged) = try await Install.execute(version: latestVersion, &config, useInstalledToolchain: true, verifySignature: true, verbose: verbose, assumeYes: assumeYes)
            }

            if addEnvToProfile {
                try Data(sourceLine.utf8).append(to: profileHome)

                if !quietShellFollowup {
                    SwiftlyCore.print("""
                    To begin using installed swiftly from your current shell, first run the following command:
                        \(sourceLine)

                    """)
                }
            }

            // Fish doesn't have path caching, so this might only be needed for bash/zsh
            if pathChanged && !quietShellFollowup && !shell.hasSuffix("fish") {
                SwiftlyCore.print("""
                Your shell caches items on your path for better performance. Swiftly has added
                items to your path that may not get picked up right away. You can update your
                shell's environment by running

                hash -r

                or restarting your shell.

                """)
            }

            if let postInstall {
                SwiftlyCore.print("""
                There are some dependencies that should be installed before using this toolchain.
                You can run the following script as the system administrator (e.g. root) to prepare
                your system:

                    \(postInstall)

                """)
            }
        }
    }
}
