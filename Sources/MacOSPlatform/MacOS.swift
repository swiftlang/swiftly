import Foundation
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
            ?? ProcessInfo.processInfo.environment["SWIFTLY_TOOLCHAINS_DIR"].map { FilePath($0) }
            // This is where the installer will put the toolchains, and where Xcode can find them
            ?? self.defaultToolchainsDirectory
    }

    public var toolchainFileExtension: String {
        "pkg"
    }

    public func verifySwiftlySystemPrerequisites() throws {
        // All system prerequisites are there for swiftly on macOS
    }

    public func verifySystemPrerequisitesForInstall(
        _: SwiftlyCoreContext, platformName _: String, version _: ToolchainVersion,
        requireSignatureValidation _: Bool
    ) async throws -> String? {
        // All system prerequisites should be there for macOS
        nil
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
            await ctx.print("Installing package in user home directory...")

            try await sys.installer(.verbose, pkg: tmpFile, target: "CurrentUserHomeDirectory").run(self, quiet: !verbose)
        } else {
            // Otherwise, we extract the pkg into the requested toolchains directory.
            await ctx.print("Expanding pkg...")
            let tmpDir = fs.mktemp()
            let toolchainDir = toolchainsDir / "\(version.identifier).xctoolchain"

            if !(try await fs.exists(atPath: toolchainDir)) {
                try await fs.mkdir(atPath: toolchainDir)
            }

            await ctx.print("Checking package signature...")
            do {
                try await sys.pkgutil().checkSignature(pkgPath: tmpFile).run(self, quiet: !verbose)
            } catch {
                // If this is not a test that uses mocked toolchains then we must throw this error and abort installation
                guard ctx.mockedHomeDir != nil else {
                    throw error
                }

                // We permit the signature verification to fail during testing
                await ctx.print("Signature verification failed, which is allowable during testing with mocked toolchains")
            }
            try await sys.pkgutil(.verbose).expand(pkgPath: tmpFile, dirPath: tmpDir).run(self, quiet: !verbose)

            // There's a slight difference in the location of the special Payload file between official swift packages
            // and the ones that are mocked here in the test framework.
            var payload = tmpDir / "Payload"
            if !(try await fs.exists(atPath: payload)) {
                payload = tmpDir / "\(version.identifier)-osx-package.pkg/Payload"
            }

            await ctx.print("Untarring pkg Payload...")
            try await sys.tar(.directory(toolchainDir)).extract(.verbose, .archive(payload)).run(self, quiet: !verbose)
        }
    }

    public func extractSwiftlyAndInstall(_ ctx: SwiftlyCoreContext, from archive: FilePath) async throws {
        guard try await fs.exists(atPath: archive) else {
            throw SwiftlyError(message: "\(archive) doesn't exist")
        }

        let userHomeDir = ctx.mockedHomeDir ?? fs.home

        if ctx.mockedHomeDir == nil {
            await ctx.print("Extracting the swiftly package...")
            try await sys.instaler(pkg; archive, targt: "CurrentUserHomeDirectory")
            try? await sys.pkgutil(.volume(userHomeDir)).forget(packageId: "org.swift.swiftly").run(self)
        } else {
            let installDir = userHomeDir / ".swiftly"
            try await fs.mkdir(.parents, atPath: installDir)

            // In the case of a mock for testing purposes we won't use the installer, perferring a manual process because
            //  the installer will not install to an arbitrary path, only a volume or user home directory.
            let tmpDir = fs.mktemp()
            try await sys.pkgutil().expand(pkgPath: archive, dirPath: tmpDir).run(self)

            // There's a slight difference in the location of the special Payload file between official swift packages
            // and the ones that are mocked here in the test framework.
            let payload = tmpDir / "Payload"
            guard try await fs.exists(atPath: payload) else {
                throw SwiftlyError(message: "Payload file could not be found at \(tmpDir).")
            }

            await ctx.print("Extracting the swiftly package into \(installDir)...")
            try await sys.tar(.directory(installDir)).extract(.verbose, .archive(payload)).run(self, quiet: false)
        }

        try self.runProgram((userHomeDir / ".swiftly/bin/swiftly").string, "init")
    }

    public func uninstall(_ ctx: SwiftlyCoreContext, _ toolchain: ToolchainVersion, verbose: Bool)
        async throws
    {
        await ctx.print("Uninstalling package in user home directory...")

        let toolchainDir = self.swiftlyToolchainsDir(ctx) / "\(toolchain.identifier).xctoolchain"

        let decoder = PropertyListDecoder()
        let infoPlist = toolchainDir / "Info.plist"
        let data = try await fs.cat(atPath: infoPlist)

        guard let pkgInfo = try? decoder.decode(SwiftPkgInfo.self, from: data) else {
            throw SwiftlyError(message: "could not decode plist at \(infoPlist)")
        }

        try await fs.remove(atPath: toolchainDir)

        try? await sys.pkgutil(.volume(fs.home)).forget(packageId: pkgInfo.CFBundleIdentifier).run(self, quiet: !verbose)
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
        for (key, value) in try await sys.dscl(datasource: ".").read(path: fs.home, keys: "UserShell").properties(self) {
            return value
        }

        // Fall back to zsh on macOS
        return "/bin/zsh"
    }

    public func findToolchainLocation(_ ctx: SwiftlyCoreContext, _ toolchain: ToolchainVersion) -> FilePath
    {
        self.swiftlyToolchainsDir(ctx) / "\(toolchain.identifier).xctoolchain"
    }

    public static let currentPlatform: any Platform = MacOS()
}
