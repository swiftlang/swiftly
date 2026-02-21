import ArgumentParser
import Foundation
import SwiftlyCore
import SystemPackage

public enum SwiftlyVersionMigration {
    case exact(SwiftlyVersion)
    case minor(SwiftlyVersion)

    public func matches(_ version: SwiftlyVersion) -> Bool {
        switch self {
        case let .exact(v):
            return version.major == v.major && version.minor == v.minor && version.patch == v.patch && version.suffix == v.suffix
        case let .minor(v):
            return version.major == v.major && version.minor == v.minor
        }
    }
}

public var migrations: [SwiftlyVersionMigration] {
    [
        .exact(.init(major: 0, minor: 4, patch: 0, suffix: "dev")),
        .exact(.init(major: 0, minor: 4, patch: 0)),
        .minor(.init(major: 1, minor: 0, patch: 0)),
        .minor(.init(major: 1, minor: 1, patch: 0)),
        .minor(.init(major: 1, minor: 2, patch: 0)),
    ]
}

struct Init: SwiftlyCommand {
    public static let configuration = CommandConfiguration(
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
        try await self.run(Swiftly.createDefaultContext())
    }

    mutating func run(_ ctx: SwiftlyCoreContext = Swiftly.createDefaultContext()) async throws {
        try await Self.execute(ctx, assumeYes: self.root.assumeYes, noModifyProfile: self.noModifyProfile, overwrite: self.overwrite, platform: self.platform, verbose: self.root.verbose, skipInstall: self.skipInstall, quietShellFollowup: self.quietShellFollowup)
    }

    /// Initialize the installation of swiftly.
    static func execute(_ ctx: SwiftlyCoreContext, assumeYes: Bool, noModifyProfile: Bool, overwrite: Bool, platform: String?, verbose: Bool, skipInstall: Bool, quietShellFollowup: Bool) async throws {
        try await Swiftly.currentPlatform.verifySwiftlySystemPrerequisites()

        var config = try? await Config.load(ctx)

        func oldEnvSh(_ ctx: SwiftlyCoreContext) -> String {
            """
            export SWIFTLY_HOME_DIR="\(Swiftly.currentPlatform.swiftlyHomeDir(ctx))"
            export SWIFTLY_BIN_DIR="\(Swiftly.currentPlatform.swiftlyBinDir(ctx))"
            export SWIFTLY_TOOLCHAINS_DIR="\(Swiftly.currentPlatform.swiftlyToolchainsDir(ctx))"
            if [[ ":$PATH:" != *":$SWIFTLY_BIN_DIR:"* ]]; then
                export PATH="$SWIFTLY_BIN_DIR:$PATH"
            fi

            """
        }

        func oldEnvFish(_ ctx: SwiftlyCoreContext) -> String {
            """
            set -x SWIFTLY_HOME_DIR "\(Swiftly.currentPlatform.swiftlyHomeDir(ctx))"
            set -x SWIFTLY_BIN_DIR "\(Swiftly.currentPlatform.swiftlyBinDir(ctx))"
            set -x SWIFTLY_TOOLCHAINS_DIR "\(Swiftly.currentPlatform.swiftlyToolchainsDir(ctx))"
            if not contains "$SWIFTLY_BIN_DIR" $PATH
                set -x PATH "$SWIFTLY_BIN_DIR" $PATH
            end

            """
        }

        func envSh(_ ctx: SwiftlyCoreContext) -> String {
            """
            export SWIFTLY_HOME_DIR="\(Swiftly.currentPlatform.swiftlyHomeDir(ctx))"
            export SWIFTLY_BIN_DIR="\(Swiftly.currentPlatform.swiftlyBinDir(ctx))"
            export SWIFTLY_TOOLCHAINS_DIR="\(Swiftly.currentPlatform.swiftlyToolchainsDir(ctx))"

            # Remove SWIFTLY_BIN_DIR from PATH if present, then prepend it
            PATH="${PATH//:$SWIFTLY_BIN_DIR/}"
            PATH="${PATH/#$SWIFTLY_BIN_DIR:/}"
            export PATH="$SWIFTLY_BIN_DIR:$PATH"

            """
        }

        func envFish(_ ctx: SwiftlyCoreContext) -> String {
            """
            set -x SWIFTLY_HOME_DIR "\(Swiftly.currentPlatform.swiftlyHomeDir(ctx))"
            set -x SWIFTLY_BIN_DIR "\(Swiftly.currentPlatform.swiftlyBinDir(ctx))"
            set -x SWIFTLY_TOOLCHAINS_DIR "\(Swiftly.currentPlatform.swiftlyToolchainsDir(ctx))"

            # Remove SWIFTLY_BIN_DIR from PATH if present, then prepend it
            fish_add_path -mP "$SWIFTLY_BIN_DIR"

            """
        }

        if var config, !overwrite && !migrations.filter({ $0.matches(config.version) }).isEmpty {
            // This is a simple upgrade from the 0.4.0 pre-releases, or 1.x

            // Move our executable over to the correct place
            try await Swiftly.currentPlatform.installSwiftlyBin(ctx)

            // Check for an outdated env.sh, and update it if the contents is recognized.
            if case let envFile = (Swiftly.currentPlatform.swiftlyHomeDir(ctx)) / "env.sh",
               (try? await fs.exists(atPath: envFile)) ?? false,
               let contents = String(data: (try? await fs.cat(atPath: envFile)) ?? Data(), encoding: .utf8),
               contents == oldEnvSh(ctx)
            {
                await ctx.print("Updating shell environment \(envFile)")
                try Data(envSh(ctx).utf8).write(to: envFile, options: .atomic)
            }

            // Check for an outdated env.fish, and update it if the contents is recognized.
            if case let envFile = (Swiftly.currentPlatform.swiftlyHomeDir(ctx)) / "env.fish",
               (try? await fs.exists(atPath: envFile)) ?? false,
               let contents = String(data: (try? await fs.cat(atPath: envFile)) ?? Data(), encoding: .utf8),
               contents == oldEnvFish(ctx)
            {
                await ctx.print("Updating fish shell environment \(envFile)")
                try Data(envFish(ctx).utf8).write(to: envFile, options: .atomic)
            }

            // Update and save the version
            config.version = SwiftlyCore.version

            try config.save(ctx)

            return
        }

        if let config, !overwrite && config.version != SwiftlyCore.version {
            // We don't support downgrades, and versions prior to 0.4.0-dev
            throw SwiftlyError(message: "An existing swiftly installation was detected. You can try again with '--overwrite' to overwrite it.")
        }

        // Give the user the prompt and the choice to abort at this point.
        if !assumeYes {
            let toolchainsDir = Swiftly.currentPlatform.swiftlyToolchainsDir(ctx)

            var msg = """
            Welcome to swiftly, the Swift toolchain manager for Linux and macOS!

            Please read the following information carefully before proceeding with the installation. If you
            wish to customize the steps performed during the installation process, refer to 'swiftly init -h'
            for configuration options.

            Swiftly installs files into the following locations:

            \(Swiftly.currentPlatform.swiftlyHomeDir(ctx)) - Directory for configuration files
            \(Swiftly.currentPlatform.swiftlyBinDir(ctx)) - Links to the binaries of the active toolchain
            \(toolchainsDir) - Directory hosting installed toolchains

            These locations can be changed by setting the environment variables
            SWIFTLY_HOME_DIR, SWIFTLY_BIN_DIR, and SWIFTLY_TOOLCHAINS_DIR before running 'swiftly init' again.

            """
#if os(macOS)
            if toolchainsDir != fs.home / "Library/Developer/Toolchains" {
                msg += """

                NOTE: The toolchains are not being installed in a standard macOS location, so Xcode may not be able to find them.
                """
            }
#endif
            if !skipInstall {
                msg += """

                Once swiftly is set up, it will install the latest available Swift toolchain. This can be
                suppressed with the '--skip-install' option.
                """
#if os(Linux)
                msg += """
                 In the process, swiftly will add swift.org
                GnuPG keys into your keychain to verify the integrity of the downloads.

                """
#else
                msg += "\n"
#endif
            }
            if !noModifyProfile {
                msg += """

                For your convenience, swiftly will also attempt to modify your shell's profile file to make
                installed items available in your environment upon login. This can be suppressed with the
                '--no-modify-profile' option.

                """
            }

            await ctx.message(msg)

            guard await ctx.promptForConfirmation(defaultBehavior: true) else {
                throw SwiftlyError(message: "swiftly installation has been cancelled")
            }
        }

        let shell = if let mockedShell = ctx.mockedShell {
            mockedShell
        } else {
            if let s = ProcessInfo.processInfo.environment["SHELL"] {
                s
            } else {
                try await Swiftly.currentPlatform.getShell()
            }
        }

        let envFile: FilePath
        let sourceLine: String
        if shell.hasSuffix("fish") {
            envFile = Swiftly.currentPlatform.swiftlyHomeDir(ctx) / "env.fish"
            sourceLine = """

            # Added by swiftly
            source "\(envFile)"
            """
        } else {
            envFile = Swiftly.currentPlatform.swiftlyHomeDir(ctx) / "env.sh"
            sourceLine = """

            # Added by swiftly
            . "\(envFile)"
            """
        }

        if overwrite {
            try? await fs.remove(atPath: Swiftly.currentPlatform.swiftlyToolchainsDir(ctx))
            try? await fs.remove(atPath: Swiftly.currentPlatform.swiftlyHomeDir(ctx))
        }

        // Go ahead and create the directories as needed
        for requiredDir in Swiftly.requiredDirectories(ctx) {
            if !(try await fs.exists(atPath: requiredDir)) {
                do {
                    try await fs.mkdir(.parents, atPath: requiredDir)
                } catch {
                    throw SwiftlyError(message: "Failed to create required directory \"\(requiredDir)\": \(error)")
                }
            }
        }

        // Force the configuration to be present. Generate it if it doesn't already exist or overwrite is set
        if overwrite || config == nil {
            let pd = try await Swiftly.currentPlatform.detectPlatform(ctx, disableConfirmation: assumeYes, platform: platform)
            let c = Config(inUse: nil, installedToolchains: [], platform: pd, version: SwiftlyCore.version)

            try c.save(ctx)
            config = c
        }

        guard var config else { throw SwiftlyError(message: "Configuration could not be set") }

        // Move our executable over to the correct place
        try await Swiftly.currentPlatform.installSwiftlyBin(ctx)

        let envFileExists = try await fs.exists(atPath: envFile)

        if overwrite || !envFileExists {
            await ctx.message("Creating shell environment file for the user...")
            var env = ""
            if shell.hasSuffix("fish") {
                env = envFish(ctx)
            } else {
                env = envSh(ctx)
            }

            try Data(env.utf8).write(to: envFile, options: .atomic)
        }

        if !noModifyProfile {
            await ctx.message("Updating profile...")

            let userHome = ctx.mockedHomeDir ?? fs.home

            let profileHome: FilePath
            if shell.hasSuffix("zsh") {
                profileHome = userHome / ".zprofile"
            } else if shell.hasSuffix("bash") {
                if case let p = userHome / ".bash_profile", try await fs.exists(atPath: p) {
                    profileHome = p
                } else if case let p = userHome / ".bash_login", try await fs.exists(atPath: p) {
                    profileHome = p
                } else {
                    profileHome = userHome / ".profile"
                }
            } else if shell.hasSuffix("fish") {
                if let xdgConfigHome = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"], case let xdgConfigURL = FilePath(xdgConfigHome) {
                    let confDir = xdgConfigURL / "fish/conf.d"
                    try await fs.mkdir(.parents, atPath: confDir)
                    profileHome = confDir / "swiftly.fish"
                } else {
                    let confDir = userHome / ".config/fish/conf.d"
                    try await fs.mkdir(.parents, atPath: confDir)
                    profileHome = confDir / "swiftly.fish"
                }
            } else {
                profileHome = userHome / ".profile"
            }

            var addEnvToProfile = false
            do {
                if !(try await fs.exists(atPath: profileHome)) {
                    addEnvToProfile = true
                } else if case let profileContents = try String(contentsOf: profileHome, encoding: .utf8), !profileContents.contains(sourceLine) {
                    addEnvToProfile = true
                }
            } catch {
                addEnvToProfile = true
            }

            if addEnvToProfile {
                try Data(sourceLine.utf8).append(to: profileHome)
            }
        }

        var postInstall: String?
        var pathChanged = false

        if !skipInstall {
            let latestVersion = try await Install.resolve(ctx, config: config, selector: ToolchainSelector.latest)
            (postInstall, pathChanged) = try await Install.execute(ctx, version: latestVersion, &config, useInstalledToolchain: true, verifySignature: true, verbose: verbose, assumeYes: assumeYes)
        }

        if !quietShellFollowup {
            await ctx.message("""
            To begin using installed swiftly from your current shell, first run the following command:
                \(sourceLine)

            """)
        }

        if pathChanged && !quietShellFollowup {
            try await Self.handlePathChange(ctx)
        }

        if let postInstall {
            // This is an unwrapped message to avoid line wrapping of the
            // post install script. When it is wrapped then it is harder to copy and paste
            // the contents from the terminal.
            await ctx.message(Messages.postInstall(postInstall), wrap: false)
        }
    }
}
