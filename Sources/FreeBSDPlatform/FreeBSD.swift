#if os(FreeBSD)
import Foundation
import Subprocess
import SwiftlyCore
import SystemPackage

typealias sys = SwiftlyCore.SystemCommand
typealias fs = SwiftlyCore.FileSystem

/// `Platform` implementation for FreeBSD.
public struct FreeBSD: Platform {
    let freebsdPlatforms: [PlatformDefinition] = [.freebsd]

    public init() {}

    public var defaultSwiftlyHomeDir: FilePath {
        if let dir = ProcessInfo.processInfo.environment["XDG_DATA_HOME"] {
            FilePath(dir) / "swiftly"
        } else {
            fs.home / ".local/share/swiftly"
        }
    }

    public func swiftlyBinDir(_ ctx: SwiftlyCoreContext) -> FilePath {
        ctx.mockedHomeDir.map { $0 / "bin" }
            ?? ProcessInfo.processInfo.environment["SWIFTLY_BIN_DIR"].map { FilePath($0) }
            ?? fs.home / ".local/share/swiftly/bin"
    }

    public func swiftlyToolchainsDir(_ ctx: SwiftlyCoreContext) -> FilePath {
        ctx.mockedHomeDir.map { $0 / "toolchains" }
            ?? ProcessInfo.processInfo.environment["SWIFTLY_TOOLCHAINS_DIR"].map { FilePath($0) }
            ?? fs.home / ".local/share/swiftly/toolchains"
    }

    public var toolchainFileExtension: String {
        "tar.gz"
    }

    private static let skipVerificationMessage: String =
        "To skip signature verification, specify the --no-verify flag."

    public func verifySwiftlySystemPrerequisites() async throws {
        // Check if the root CA certificates are installed on this system for NIOSSL to use.
        // On FreeBSD the trust store is provided by the security/ca_root_nss port
        // (/usr/local/etc/ssl/cert.pem); /etc/ssl/cert.pem is the base system bundle.
        var foundTrustedCAs = false
        for crtFile in ["/usr/local/etc/ssl/cert.pem", "/etc/ssl/cert.pem", "/usr/local/share/certs/ca-root-nss.crt"] {
            if try await fs.exists(atPath: FilePath(crtFile)) {
                foundTrustedCAs = true
                break
            }
        }

        if !foundTrustedCAs {
            let msg = """
            The ca-certificates package is not installed. Swiftly won't be able to trust the sites to
            perform its downloads.

            You can install the ca-certificates package on your system to fix this.
            """

            throw SwiftlyError(message: msg)
        }
    }

    public func verifySystemPrerequisitesForInstall(
        _ ctx: SwiftlyCoreContext, platformName _: String, version _: ToolchainVersion,
        requireSignatureValidation: Bool,
    ) async throws -> String? {
        // FreeBSD runtime dependencies for a Swift toolchain, per
        // https://github.com/swiftlang/swift-installer-scripts/blob/main/platforms/FreeBSD/makePackage
        let packages: [String] = [
            "libuuid",
            "python311",
            "sqlite3",
        ]

        if requireSignatureValidation {
            let result = try await run(
                .name("gpg"),
                arguments: ["--version"],
                output: .discarded,
            )

            if !result.terminationStatus.isSuccess {
                let msg = "gpg is not installed. " +
                    "You can install it by running: pkg install gnupg\n" +
                    Self.skipVerificationMessage
                throw SwiftlyError(message: msg)
            }

            try await self.importGpgKeys(ctx)
        }

        var missingPackages: [String] = []

        for pkg in packages {
            if await !self.isSystemPackageInstalled(pkg) {
                missingPackages.append(pkg)
            }
        }

        guard !missingPackages.isEmpty else {
            return nil
        }

        return "pkg install \(missingPackages.joined(separator: " "))"
    }

    public func isSystemPackageInstalled(_ package: String) async -> Bool {
        do {
            let result = try await run(.name("pkg"), arguments: ["info", "-e", package], output: .discarded)
            return result.terminationStatus.isSuccess
        } catch {
            return false
        }
    }

    public func install(
        _ ctx: SwiftlyCoreContext, from tmpFile: FilePath, version: ToolchainVersion, verbose: Bool,
    ) async throws {
        guard try await fs.exists(atPath: tmpFile) else {
            throw SwiftlyError(message: "\(tmpFile) doesn't exist")
        }

        if try await !(fs.exists(atPath: self.swiftlyToolchainsDir(ctx))) {
            try await fs.mkdir(atPath: self.swiftlyToolchainsDir(ctx))
        }

        await ctx.message("Extracting toolchain...")
        let toolchainDir = self.swiftlyToolchainsDir(ctx) / version.name

        if try await fs.exists(atPath: toolchainDir) {
            try await fs.remove(atPath: toolchainDir)
        }

        try extractArchive(atPath: tmpFile) { name in
            // drop swift-a.b.c-RELEASE etc name from the extracted files.
            let relativePath = name.drop { c in c != "/" }.dropFirst()

            // prepend /path/to/swiftlyHomeDir/toolchains/<toolchain> to each file name
            let destination = toolchainDir / String(relativePath)

            if verbose {
                // To avoid having to make extractArchive async this is a regular print
                //  to stdout. Note that it is unlikely that the test mocking will require
                //  capturing this output.
                print("\(destination)")
            }

            // prepend /path/to/swiftlyHomeDir/toolchains/<toolchain> to each file name
            return destination
        }
    }

    public func extractSwiftlyAndInstall(_ ctx: SwiftlyCoreContext, from archive: FilePath) async throws {
        guard try await fs.exists(atPath: archive) else {
            throw SwiftlyError(message: "\(archive) doesn't exist")
        }

        let tmpDir = self.getTempFilePath()
        try await fs.mkdir(.parents, atPath: tmpDir)
        try await fs.withTemporary(files: tmpDir) {
            await ctx.message("Extracting new swiftly...")
            try extractArchive(atPath: archive) { name in
                // Extract to the temporary directory
                tmpDir / String(name)
            }

            let config = Configuration(
                executable: .path(tmpDir / "swiftly"),
                arguments: ["init"]
            )

            let result = try await run(config, output: .currentStandardOutput, error: .currentStandardError)
            if !result.terminationStatus.isSuccess {
                throw RunProgramError(terminationStatus: result.terminationStatus, config: config)
            }
        }
    }

    public func uninstall(_ ctx: SwiftlyCoreContext, _ toolchain: ToolchainVersion, verbose _: Bool) async throws {
        let toolchainDir = self.swiftlyToolchainsDir(ctx) / toolchain.name
        try await fs.remove(atPath: toolchainDir)
    }

    public func getExecutableName() -> String {
        let arch = cpuArch

        return "swiftly-\(arch)-unknown-freebsd"
    }

    public func getTempFilePath() -> FilePath {
        fs.tmp / "swiftly-\(UUID())"
    }

    public func verifyToolchainSignature(
        _ ctx: SwiftlyCoreContext, toolchainFile: ToolchainFile, archive: FilePath, verbose: Bool,
    ) async throws {
        // Ensure GPG keys are imported before attempting signature verification
        try await self.importGpgKeys(ctx)

        if verbose {
            await ctx.message("Downloading toolchain signature...")
        }

        let sigFile = self.getTempFilePath()
        try await fs.create(file: sigFile, contents: nil)
        try await fs.withTemporary(files: sigFile) {
            try await ctx.httpClient.getSwiftToolchainFileSignature(toolchainFile).download(to: sigFile)

            await ctx.message("Verifying toolchain signature...")
            do {
                if let mockedHomeDir = ctx.mockedHomeDir {
                    try await sys.gpg().verify(detached_signature: sigFile, signed_data: archive).run(environment: .inherit.updating(["GNUPGHOME": (mockedHomeDir / ".gnupg").string]), quiet: false)
                } else {
                    try await sys.gpg().verify(detached_signature: sigFile, signed_data: archive).run(quiet: !verbose)
                }
            } catch {
                throw SwiftlyError(message: "Signature verification failed: \(error).")
            }
        }
    }

    /// Import Swift.org GPG keys for signature verification
    private func importGpgKeys(_ ctx: SwiftlyCoreContext) async throws {
        let tmpFile = self.getTempFilePath()
        try await fs.create(.mode(0o600), file: tmpFile, contents: nil)
        try await fs.withTemporary(files: tmpFile) {
            try await ctx.httpClient.getGpgKeys().download(to: tmpFile)
            if let mockedHomeDir = ctx.mockedHomeDir {
                try await sys.gpg()._import(key: tmpFile).run(environment: .inherit.updating(["GNUPGHOME": (mockedHomeDir / ".gnupg").string]), quiet: true)
            } else {
                try await sys.gpg()._import(key: tmpFile).run(quiet: true)
            }
        }
    }

    public func verifySwiftlySignature(
        _ ctx: SwiftlyCoreContext, archiveDownloadURL: URL, archive: FilePath, verbose: Bool,
    ) async throws {
        // Ensure GPG keys are imported before attempting signature verification
        try await self.importGpgKeys(ctx)

        if verbose {
            await ctx.message("Downloading swiftly signature...")
        }

        let sigFile = self.getTempFilePath()
        try await fs.create(file: sigFile, contents: nil)
        try await fs.withTemporary(files: sigFile) {
            try await ctx.httpClient.getSwiftlyReleaseSignature(
                url: archiveDownloadURL.appendingPathExtension("sig"),
            ).download(to: sigFile)

            await ctx.message("Verifying swiftly signature...")
            do {
                if let mockedHomeDir = ctx.mockedHomeDir {
                    try await sys.gpg().verify(detached_signature: sigFile, signed_data: archive).run(environment: .inherit.updating(["GNUPGHOME": (mockedHomeDir / ".gnupg").string]), quiet: false)
                } else {
                    try await sys.gpg().verify(detached_signature: sigFile, signed_data: archive).run(quiet: !verbose)
                }
            } catch {
                throw SwiftlyError(message: "Signature verification failed: \(error).")
            }
        }
    }

    public func detectPlatform(
        _: SwiftlyCoreContext, disableConfirmation _: Bool, platform: String?
    ) async throws -> PlatformDefinition {
        // Swift.org does not currently publish FreeBSD toolchains, so there is a single
        // supported platform definition. A platform hint, if provided, must match it.
        if let platform {
            guard let pd = self.freebsdPlatforms.first(where: { $0.nameFull == platform }) else {
                throw SwiftlyError(
                    message: "Unrecognized platform \(platform). Supported values: \(self.freebsdPlatforms.map(\.nameFull).joined(separator: ", "))."
                )
            }
            return pd
        }
        return .freebsd
    }

    public func getShell() async throws -> String {
        let userName = ProcessInfo.processInfo.userName
        if let entry = try await sys.getent(database: "passwd", key: userName).entries().first {
            if let shell = entry.last { return shell }
        }

        // Fall back on sh — bash is not installed by default on FreeBSD
        return "/bin/sh"
    }

    public func findToolchainLocation(_ ctx: SwiftlyCoreContext, _ toolchain: ToolchainVersion) -> FilePath {
        self.swiftlyToolchainsDir(ctx) / "\(toolchain.name)"
    }

    public func updateEnvironmentWithToolchain(_: SwiftlyCoreContext, _ environment: Environment, _: ToolchainVersion, path _: String) async throws -> Environment {
        // No explicit environment customization on FreeBSD
        environment
    }

    public static let currentPlatform: any Platform = FreeBSD()
}

#endif
