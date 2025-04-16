import Foundation
import SwiftlyCore

public struct SwiftPkgInfo: Codable {
    public var CFBundleIdentifier: String

    public init(CFBundleIdentifier: String) {
        self.CFBundleIdentifier = CFBundleIdentifier
    }
}

/// `Platform` implementation for macOS systems.
public struct MacOS: Platform {
    public init() {}

    public var defaultSwiftlyHomeDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".swiftly", isDirectory: true)
    }

    public var defaultToolchainsDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Developer/Toolchains", isDirectory: true)
    }

    public func swiftlyBinDir(_ ctx: SwiftlyCoreContext) -> URL {
        ctx.mockedHomeDir.map { $0.appendingPathComponent("bin", isDirectory: true) }
            ?? ProcessInfo.processInfo.environment["SWIFTLY_BIN_DIR"].map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".swiftly/bin", isDirectory: true)
    }

    public func swiftlyToolchainsDir(_ ctx: SwiftlyCoreContext) -> URL {
        ctx.mockedHomeDir.map { $0.appendingPathComponent("Toolchains", isDirectory: true) }
            ?? ProcessInfo.processInfo.environment["SWIFTLY_TOOLCHAINS_DIR"].map { URL(fileURLWithPath: $0) }
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
        _ ctx: SwiftlyCoreContext, from tmpFile: URL, version: ToolchainVersion, verbose: Bool
    ) async throws {
        guard tmpFile.fileExists() else {
            throw SwiftlyError(message: "\(tmpFile) doesn't exist")
        }

        let toolchainsDir = self.swiftlyToolchainsDir(ctx)

        if !toolchainsDir.fileExists() {
            try FileManager.default.createDirectory(
                at: self.swiftlyToolchainsDir(ctx), withIntermediateDirectories: true
            )
        }

        if toolchainsDir == self.defaultToolchainsDirectory {
            // If the toolchains go into the default user location then we use the installer to install them
            await ctx.print("Installing package in user home directory...")
            try runProgram(
                "installer", "-verbose", "-pkg", tmpFile.path, "-target", "CurrentUserHomeDirectory",
                quiet: !verbose
            )
        } else {
            // Otherwise, we extract the pkg into the requested toolchains directory.
            await ctx.print("Expanding pkg...")
            let tmpDir = self.getTempFilePath()
            let toolchainDir = toolchainsDir.appendingPathComponent(
                "\(version.identifier).xctoolchain", isDirectory: true
            )

            if !toolchainDir.fileExists() {
                try FileManager.default.createDirectory(
                    at: toolchainDir, withIntermediateDirectories: false
                )
            }

            await ctx.print("Checking package signature...")
            do {
                try runProgram("pkgutil", "--check-signature", tmpFile.path, quiet: !verbose)
            } catch {
                // If this is not a test that uses mocked toolchains then we must throw this error and abort installation
                guard ctx.mockedHomeDir != nil else {
                    throw error
                }

                // We permit the signature verification to fail during testing
                await ctx.print("Signature verification failed, which is allowable during testing with mocked toolchains")
            }
            try runProgram("pkgutil", "--verbose", "--expand", tmpFile.path, tmpDir.path, quiet: !verbose)
            // There's a slight difference in the location of the special Payload file between official swift packages
            // and the ones that are mocked here in the test framework.
            var payload = tmpDir.appendingPathComponent("Payload")
            if !payload.fileExists() {
                payload = tmpDir.appendingPathComponent("\(version.identifier)-osx-package.pkg/Payload")
            }

            await ctx.print("Untarring pkg Payload...")
            try runProgram("tar", "-C", toolchainDir.path, "-xvf", payload.path, quiet: !verbose)
        }
    }

    public func extractSwiftlyAndInstall(_ ctx: SwiftlyCoreContext, from archive: URL) async throws {
        guard archive.fileExists() else {
            throw SwiftlyError(message: "\(archive) doesn't exist")
        }

        let homeDir: URL

        if ctx.mockedHomeDir == nil {
            homeDir = FileManager.default.homeDirectoryForCurrentUser

            await ctx.print("Extracting the swiftly package...")
            try runProgram("installer", "-pkg", archive.path, "-target", "CurrentUserHomeDirectory")
            try? runProgram("pkgutil", "--volume", homeDir.path, "--forget", "org.swift.swiftly")
        } else {
            homeDir = ctx.mockedHomeDir ?? FileManager.default.homeDirectoryForCurrentUser

            let installDir = homeDir.appendingPathComponent(".swiftly")
            try FileManager.default.createDirectory(
                atPath: installDir.path, withIntermediateDirectories: true
            )

            // In the case of a mock for testing purposes we won't use the installer, perferring a manual process because
            //  the installer will not install to an arbitrary path, only a volume or user home directory.
            let tmpDir = self.getTempFilePath()
            try runProgram("pkgutil", "--expand", archive.path, tmpDir.path)

            // There's a slight difference in the location of the special Payload file between official swift packages
            // and the ones that are mocked here in the test framework.
            let payload = tmpDir.appendingPathComponent("Payload")
            guard payload.fileExists() else {
                throw SwiftlyError(message: "Payload file could not be found at \(tmpDir).")
            }

            await ctx.print("Extracting the swiftly package into \(installDir.path)...")
            try runProgram("tar", "-C", installDir.path, "-xvf", payload.path, quiet: false)
        }

        try self.runProgram(homeDir.appendingPathComponent(".swiftly/bin/swiftly").path, "init")
    }

    public func uninstall(_ ctx: SwiftlyCoreContext, _ toolchain: ToolchainVersion, verbose: Bool)
        async throws
    {
        await ctx.print("Uninstalling package in user home directory...")

        let toolchainDir = self.swiftlyToolchainsDir(ctx).appendingPathComponent(
            "\(toolchain.identifier).xctoolchain", isDirectory: true
        )

        let decoder = PropertyListDecoder()
        let infoPlist = toolchainDir.appendingPathComponent("Info.plist")
        guard let data = try? Data(contentsOf: infoPlist) else {
            throw SwiftlyError(message: "could not open \(infoPlist.path)")
        }

        guard let pkgInfo = try? decoder.decode(SwiftPkgInfo.self, from: data) else {
            throw SwiftlyError(message: "could not decode plist at \(infoPlist.path)")
        }

        try FileManager.default.removeItem(at: toolchainDir)

        let homedir = ProcessInfo.processInfo.environment["HOME"]!
        try? runProgram(
            "pkgutil", "--volume", homedir, "--forget", pkgInfo.CFBundleIdentifier, quiet: !verbose
        )
    }

    public func getExecutableName() -> String {
        "swiftly-macos-osx"
    }

    public func getTempFilePath() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("swiftly-\(UUID()).pkg")
    }

    public func verifyToolchainSignature(
        _: SwiftlyCoreContext, toolchainFile _: ToolchainFile, archive _: URL, verbose _: Bool
    ) async throws {
        // No signature verification is required on macOS since the pkg files have their own signing
        //  mechanism and the swift.org downloadables are trusted by stock macOS installations.
    }

    public func verifySwiftlySignature(
        _: SwiftlyCoreContext, archiveDownloadURL _: URL, archive _: URL, verbose _: Bool
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
        if let directoryInfo = try await runProgramOutput(
            "dscl", ".", "-read", FileManager.default.homeDirectoryForCurrentUser.path
        ) {
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

    public func findToolchainLocation(_ ctx: SwiftlyCoreContext, _ toolchain: ToolchainVersion) -> URL
    {
        self.swiftlyToolchainsDir(ctx).appendingPathComponent("\(toolchain.identifier).xctoolchain")
    }

    public static let currentPlatform: any Platform = MacOS()
}
