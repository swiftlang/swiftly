import Foundation
import Subprocess
import SwiftlyCore
import SystemPackage

typealias sys = SwiftlyCore.SystemCommand
typealias fs = SwiftlyCore.FileSystem

public struct SwiftPkgInfo: Codable {
    public var CFBundleIdentifier: String

    public init(CFBundleIdentifier: String) {
        self.CFBundleIdentifier = CFBundleIdentifier
    }
}

/// `Platform` implementation for macOS systems.
public struct MacOS: Platform {
    public init() {}

    private let SWIFTLY_TOOLCHAINS_DIR = "SWIFTLY_TOOLCHAINS_DIR"

    public var defaultSwiftlyHomeDir: FilePath {
        fs.home / ".swiftly"
    }

    public var defaultToolchainsDirectory: FilePath {
        fs.home / "Library/Developer/Toolchains"
    }

    public func swiftlyBinDir(_ ctx: SwiftlyCoreContext) -> FilePath {
        ctx.mockedHomeDir.map { $0 / "bin" }
            ?? ProcessInfo.processInfo.environment["SWIFTLY_BIN_DIR"].map { FilePath($0) }
            ?? fs.home / ".swiftly/bin"
    }

    public func swiftlyToolchainsDir(_ ctx: SwiftlyCoreContext) -> FilePath {
        ctx.mockedHomeDir.map { $0 / "Toolchains" }
            ?? ProcessInfo.processInfo.environment[self.SWIFTLY_TOOLCHAINS_DIR].map { FilePath($0) }
            // This is where the installer will put the toolchains, and where Xcode can find them
            ?? self.defaultToolchainsDirectory
    }

    public var toolchainFileExtension: String {
        "pkg"
    }

    public func getSystemPrerequisites(platformName: String) -> [String] {
        return []
    }

    public func isSystemPackageInstalled(_ manager: String?, _ package: String) async -> Bool {
        return false
    }

    public func getSystemPackageManager(platformName: String) -> String? {
        return nil
    }

    public func verifySwiftlySystemPrerequisites() throws {
        // All system prerequisites are there for swiftly on macOS
    }

    public func verifySystemPrerequisitesForInstall(
        _ ctx: SwiftlyCoreContext, platformName _: String, version _: ToolchainVersion,
        requireSignatureValidation _: Bool
    ) async throws -> String? {
        // Ensure that there is in fact a macOS SDK installed so the toolchain is usable.
        let result = try await run(
            .path(SystemPackage.FilePath("/usr/bin/xcrun")),
            arguments: ["--show-sdk-path", "--sdk", "macosx"],
            output: .string(limit: 1024 * 10)
        )

        // Simply print warnings to the user stdout rather than returning a shell script, as there is not a simple
        // shell script for installing developer tools on macOS.
        if !result.terminationStatus.isSuccess {
            let msg = """
            \nWARNING: Could not find a macOS SDK on the system. A macOS SDK is required for the toolchain to work correctly. Please install one via Xcode (https://developer.apple.com/xcode) or run the following command on your machine to install the Command Line Tools for Xcode:
            xcode-select --install

            More information on installing the Command Line Tools can be found here: https://developer.apple.com/documentation/xcode/installing-the-command-line-tools/#Install-the-Command-Line-Tools-package-in-Terminal. If developer tools are located at a non-default location on disk, use the following command to specify the Xcode that you wish to use for Command Line Tools for Xcode:
            sudo xcode-select --switch path/to/Xcode.app\n
            """

            await ctx.message(msg)
        }

        let sdkPath = result.standardOutput?.replacingOccurrences(of: "\n", with: "")

        if sdkPath == nil {
            await ctx.message("WARNING: Could not read output of '/usr/bin/xcrun --show-sdk-path --sdk macosx'. Ensure your macOS SDK is installed properly for the swift toolchain to work.")
        }

        return nil
    }

    public func install(
        _ ctx: SwiftlyCoreContext, from tmpFile: FilePath, version: ToolchainVersion, verbose: Bool
    ) async throws {
        guard try await fs.exists(atPath: tmpFile) else {
            throw SwiftlyError(message: "\(tmpFile) doesn't exist")
        }

        let toolchainsDir = self.swiftlyToolchainsDir(ctx)

        if !(try await fs.exists(atPath: toolchainsDir)) {
            try await fs.mkdir(.parents, atPath: self.swiftlyToolchainsDir(ctx))
        }

        if toolchainsDir == self.defaultToolchainsDirectory {
            // If the toolchains go into the default user location then we use the installer to install them
            await ctx.message("Installing package in user home directory...")

            try await sys.installer(.verbose, .pkg(tmpFile), .target("CurrentUserHomeDirectory")).run()
        } else {
            // Otherwise, we extract the pkg into the requested toolchains directory.
            await ctx.message("Expanding pkg...")
            let tmpDir = fs.mktemp()
            let toolchainDir = toolchainsDir / "\(version.identifier).xctoolchain"

            if !(try await fs.exists(atPath: toolchainDir)) {
                try await fs.mkdir(atPath: toolchainDir)
            }

            await ctx.message("Checking package signature...")
            do {
                try await sys.pkgutil().checksignature(pkg_path: tmpFile).run(quiet: !verbose)
            } catch {
                // If this is not a test that uses mocked toolchains then we must throw this error and abort installation
                guard ctx.mockedHomeDir != nil else {
                    throw error
                }

                // We permit the signature verification to fail during testing
                await ctx.message("Signature verification failed, which is allowable during testing with mocked toolchains")
            }
            try await sys.pkgutil(.verbose).expand(pkg_path: tmpFile, dir_path: tmpDir).run(quiet: !verbose)

            // There's a slight difference in the location of the special Payload file between official swift packages
            // and the ones that are mocked here in the test framework.
            var payload = tmpDir / "Payload"
            if !(try await fs.exists(atPath: payload)) {
                payload = tmpDir / "\(version.identifier)-osx-package.pkg/Payload"
            }

            await ctx.message("Untarring pkg Payload...")
            try await sys.tar(.directory(toolchainDir)).extract(.verbose, .archive(payload)).run(quiet: !verbose)
        }
    }

    public func extractSwiftlyAndInstall(_ ctx: SwiftlyCoreContext, from archive: FilePath) async throws {
        guard try await fs.exists(atPath: archive) else {
            throw SwiftlyError(message: "\(archive) doesn't exist")
        }

        let userHomeDir = ctx.mockedHomeDir ?? fs.home

        if ctx.mockedHomeDir == nil {
            await ctx.message("Extracting the swiftly package...")
            try await sys.installer(
                .pkg(archive),
                .target("CurrentUserHomeDirectory")
            ).run()
            try? await sys.pkgutil(.volume(userHomeDir)).forget(pkg_id: "org.swift.swiftly").run()
        } else {
            let installDir = userHomeDir / ".swiftly"
            try await fs.mkdir(.parents, atPath: installDir)

            // In the case of a mock for testing purposes we won't use the installer, perferring a manual process because
            //  the installer will not install to an arbitrary path, only a volume or user home directory.
            let tmpDir = fs.mktemp()
            try await sys.pkgutil().expand(pkg_path: archive, dir_path: tmpDir).run()

            // There's a slight difference in the location of the special Payload file between official swift packages
            // and the ones that are mocked here in the test framework.
            let payload = tmpDir / "Payload"
            guard try await fs.exists(atPath: payload) else {
                throw SwiftlyError(message: "Payload file could not be found at \(tmpDir).")
            }

            await ctx.message("Extracting the swiftly package into \(installDir)...")
            try await sys.tar(.directory(installDir)).extract(.verbose, .archive(payload)).run(quiet: false)
        }

        let config = Configuration(
            .path(FilePath((userHomeDir / ".swiftly/bin/swiftly").string)), arguments: ["init"]
        )
        let result = try await run(config, input: .standardInput, output: .standardOutput, error: .standardError)
        if !result.terminationStatus.isSuccess {
            throw RunProgramError(terminationStatus: result.terminationStatus, config: config)
        }
    }

    public func uninstall(_ ctx: SwiftlyCoreContext, _ toolchain: ToolchainVersion, verbose: Bool)
        async throws
    {
        if verbose {
            await ctx.message("Uninstalling package in user home directory... ")
        }

        let toolchainDir = self.swiftlyToolchainsDir(ctx) / "\(toolchain.identifier).xctoolchain"

        let bundleID = try await findToolchainBundleID(ctx, toolchain)

        try await fs.remove(atPath: toolchainDir)

        if let bundleID {
            try? await sys.pkgutil(.volume(fs.home)).forget(pkg_id: bundleID).run(quiet: !verbose)
        }
    }

    private func findToolchainBundleID(_ ctx: SwiftlyCoreContext, _ toolchain: ToolchainVersion) async throws -> String? {
        guard toolchain != .xcode else {
            return nil
        }

        let toolchainDir = self.swiftlyToolchainsDir(ctx) / "\(toolchain.identifier).xctoolchain"

        let decoder = PropertyListDecoder()
        let infoPlist = toolchainDir / "Info.plist"
        let data = try await fs.cat(atPath: infoPlist)

        guard let pkgInfo = try? decoder.decode(SwiftPkgInfo.self, from: data) else {
            throw SwiftlyError(message: "could not decode plist at \(infoPlist)")
        }

        return pkgInfo.CFBundleIdentifier
    }

    public func getExecutableName() -> String {
        "swiftly-macos-osx"
    }

    public func verifyToolchainSignature(
        _: SwiftlyCoreContext, toolchainFile _: ToolchainFile, archive _: FilePath, verbose _: Bool
    ) async throws {
        // No signature verification is required on macOS since the pkg files have their own signing
        //  mechanism and the swift.org downloadables are trusted by stock macOS installations.
    }

    public func verifySwiftlySignature(
        _: SwiftlyCoreContext, archiveDownloadURL _: URL, archive _: FilePath, verbose _: Bool
    ) async throws {
        // No signature verification is required on macOS since the pkg files have their own signing
        //  mechanism and the swift.org downloadables are trusted by stock macOS installations.
    }

    public func detectPlatform(
        _: SwiftlyCoreContext, disableConfirmation _: Bool, platform _: String?
    ) async -> PlatformDefinition {
        // No special detection required on macOS platform
        .macOS
    }

    public func getShell() async throws -> String {
        for (_, value) in try await sys.dscl(datasource: ".").read(path: fs.home, key: ["UserShell"]).properties(self) {
            return value
        }

        // Fall back to zsh on macOS
        return "/bin/zsh"
    }

    public func findToolchainLocation(_ ctx: SwiftlyCoreContext, _ toolchain: ToolchainVersion) async throws -> FilePath
    {
        if toolchain == .xcodeVersion {
            // Print the toolchain location with the help of xcrun
            if let xcrunLocation = try? await run(.path(FilePath("/usr/bin/xcrun")), arguments: ["-f", "swift"], output: .string(limit: 1024 * 10)).standardOutput {
                return FilePath(xcrunLocation.replacingOccurrences(of: "\n", with: "")).removingLastComponent().removingLastComponent().removingLastComponent()
            }
        }

        return self.swiftlyToolchainsDir(ctx) / "\(toolchain.identifier).xctoolchain"
    }

    public func updateEnvironmentWithToolchain(_ ctx: SwiftlyCoreContext, _ environment: Environment, _ toolchain: ToolchainVersion, path: String) async throws -> Environment {
        var newEnv = environment

        // On macOS, we try to set SDKROOT if its empty for tools like clang++ that need it to
        // find standard libraries that aren't in the toolchain, like libc++. Here we
        // use xcrun to tell us what the default sdk root should be.
        if ProcessInfo.processInfo.environment["SDKROOT"] == nil {
            newEnv = newEnv.updating([
                "SDKROOT": try? await run(
                    .path(SystemPackage.FilePath("/usr/bin/xcrun")),
                    arguments: ["--show-sdk-path"],
                    output: .string(limit: 1024 * 10)
                ).standardOutput?.replacingOccurrences(of: "\n", with: ""),
            ])
        }

        guard let bundleID = try await findToolchainBundleID(ctx, toolchain) else {
            return newEnv
        }

        // If someday the two tools in the toolchain that require xcrun were to remove their dependency on it then
        // we can determine the maximum toolchain version where these environment variables are needed and abort early
        // here.

        let TOOLCHAINS: Environment.Key = "TOOLCHAINS"
        let DEVELOPER_DIR: Environment.Key = "DEVELOPER_DIR"
        let PATH: Environment.Key = "PATH"

        if let existingToolchains = ProcessInfo.processInfo.environment[TOOLCHAINS.rawValue], existingToolchains != bundleID {
            throw SwiftlyError(message: "You have already set \(TOOLCHAINS.rawValue) environment variable to \(existingToolchains), but swiftly has picked another toolchain. Please unset it or `swiftly use xcode` to use the Xcode selection mechanism.")
        }
        newEnv = newEnv.updating([TOOLCHAINS: bundleID])

        // Create a compatible DEVELOPER_DIR in case of a custom swiftly toolchain location (not ~/Library/Developer/Toolchains)
        if let swiftlyToolchainsDir = ProcessInfo.processInfo.environment[SWIFTLY_TOOLCHAINS_DIR],
           case let customToolchainsDir = FilePath(swiftlyToolchainsDir),
           customToolchainsDir != defaultToolchainsDirectory
        {
            // Simulate a custom CommandLineTools within the swiftly home directory that satisfies xcrun and allows it to find
            //  the selected toolchain on the PATH with the selected toolchain in front. This command-line tools will only have
            //  the expected libxcrun.dylib in it and no other tools in its usr/bin directory so that none are picked up there by xcrun.

            // We need a macOS CLT to be installed for this to work
            let realCltDir = FilePath("/Library/Developer/CommandLineTools")
            if !(try await fs.exists(atPath: realCltDir)) {
                throw SwiftlyError(message: "The macOS command line tools must be installed to support a custom SWIFTLY_TOOLCHAIN_DIR for macOS. You can install it using `xcode-select --install`")
            }

            let commandLineToolsDir = swiftlyHomeDir(ctx) / "CommandLineTools"
            if !(try await fs.exists(atPath: commandLineToolsDir)) {
                try await fs.mkdir(atPath: commandLineToolsDir)
            }

            let usrLibDir = commandLineToolsDir / "usr" / "lib"
            if !(try await fs.exists(atPath: usrLibDir)) {
                try await fs.mkdir(.parents, atPath: usrLibDir)
            }

            let xcrunLibLink = usrLibDir / "libxcrun.dylib"
            if !(try await fs.exists(atPath: xcrunLibLink)) {
                try await fs.symlink(atPath: xcrunLibLink, linkPath: realCltDir / "usr/lib/libxcrun.dylib")
            }

            let developerDir: FilePath = commandLineToolsDir

            if let developerDirEnv = ProcessInfo.processInfo.environment[DEVELOPER_DIR.rawValue],
               developerDirEnv != developerDir.string
            {
                throw SwiftlyError(message: "You have set \(DEVELOPER_DIR.rawValue) environment variable to \(developerDirEnv), but swiftly is trying to use its own location so that a toolchain can be selected. Please unset the environment variable and try again.")
            }

            newEnv = newEnv.updating([DEVELOPER_DIR: developerDir.string])
            newEnv = newEnv.updating([PATH: path + ":" + (realCltDir / "usr/bin").string])
        }

        return newEnv
    }

    public static let currentPlatform: any Platform = MacOS()
}
