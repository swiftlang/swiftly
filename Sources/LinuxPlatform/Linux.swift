import Foundation
import SwiftlyCore
import SystemPackage

typealias sys = SwiftlyCore.SystemCommand
typealias fs = SwiftlyCore.FileSystem

/// `Platform` implementation for Linux systems.
/// This implementation can be reused for any supported Linux platform.
/// TODO: replace dummy implementations
public struct Linux: Platform {
    let linuxPlatforms: [PlatformDefinition] = [
        .ubuntu2404,
        .ubuntu2204,
        .ubuntu2004,
        .ubuntu1804,
        .fedora39,
        .rhel9,
        .amazonlinux2,
        .debian12,
    ]

    public init() {}

    public var defaultSwiftlyHomeDir: FilePath {
        if let dir = ProcessInfo.processInfo.environment["XDG_DATA_HOME"] {
            return FilePath(dir) / "swiftly"
        } else {
            return fs.home / ".local/share/swiftly"
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
        // This list comes from LinuxCABundle.swift in NIOSSL.
        var foundTrustedCAs = false
        for crtFile in ["/etc/ssl/certs/ca-certificates.crt", "/etc/pki/tls/certs/ca-bundle.crt"] {
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
        _ ctx: SwiftlyCoreContext, platformName: String, version _: ToolchainVersion,
        requireSignatureValidation: Bool
    ) async throws -> String? {
        // TODO: these are hard-coded until we have a place to query for these based on the toolchain version
        // These lists were copied from the dockerfile sources here: https://github.com/apple/swift-docker/tree/ea035798755cce4ec41e0c6dbdd320904cef0421/5.10
        let packages: [String] =
            switch platformName
        {
        case "ubuntu1804":
            [
                "libatomic1",
                "libcurl4-openssl-dev",
                "libxml2-dev",
                "libedit2",
                "libsqlite3-0",
                "libc6-dev",
                "binutils",
                "libgcc-5-dev",
                "libstdc++-5-dev",
                "zlib1g-dev",
                "libpython3.6",
                "tzdata",
                "git",
                "unzip",
                "pkg-config",
            ]
        case "ubuntu2004":
            [
                "binutils",
                "git",
                "unzip",
                "gnupg2",
                "libc6-dev",
                "libcurl4-openssl-dev",
                "libedit2",
                "libgcc-9-dev",
                "libpython3.8",
                "libsqlite3-0",
                "libstdc++-9-dev",
                "libxml2-dev",
                "libz3-dev",
                "pkg-config",
                "tzdata",
                "zlib1g-dev",
            ]
        case "ubuntu2204":
            [
                "binutils",
                "git",
                "unzip",
                "gnupg2",
                "libc6-dev",
                "libcurl4-openssl-dev",
                "libedit2",
                "libgcc-11-dev",
                "libpython3-dev",
                "libsqlite3-0",
                "libstdc++-11-dev",
                "libxml2-dev",
                "libz3-dev",
                "pkg-config",
                "python3-lldb-13",
                "tzdata",
                "zlib1g-dev",
            ]
        case "ubuntu2404":
            [
                "binutils",
                "git",
                "unzip",
                "gnupg2",
                "libc6-dev",
                "libcurl4-openssl-dev",
                "libedit2",
                "libgcc-13-dev",
                "libpython3-dev",
                "libsqlite3-0",
                "libstdc++-13-dev",
                "libxml2-dev",
                "libncurses-dev",
                "libz3-dev",
                "pkg-config",
                "tzdata",
                "zlib1g-dev",
            ]
        case "amazonlinux2":
            [
                "binutils",
                "gcc",
                "git",
                "unzip",
                "glibc-static",
                "gzip",
                "libbsd",
                "libcurl-devel",
                "libedit",
                "libicu",
                "libsqlite",
                "libstdc++-static",
                "libuuid",
                "libxml2-devel",
                "openssl-devel",
                "tar",
                "tzdata",
                "zlib-devel",
            ]
        case "ubi9":
            [
                "git",
                "gcc-c++",
                "libcurl-devel",
                "libedit-devel",
                "libuuid-devel",
                "libxml2-devel",
                "ncurses-devel",
                "python3-devel",
                "rsync",
                "sqlite-devel",
                "unzip",
                "zip",
            ]
        case "fedora39":
            [
                "binutils",
                "gcc",
                "git",
                "unzip",
                "libcurl-devel",
                "libedit-devel",
                "libicu-devel",
                "sqlite-devel",
                "libuuid-devel",
                "libxml2-devel",
                "python3-devel",
                "libstdc++-devel",
                "libstdc++-static",
            ]
        case "debian12":
            [
                "binutils", // binutils-gold is a virtual package that points to binutils
                "libicu-dev",
                "libcurl4-openssl-dev",
                "libedit-dev",
                "libsqlite3-dev",
                "libncurses-dev",
                "libpython3-dev",
                "libxml2-dev",
                "pkg-config",
                "uuid-dev",
                "tzdata",
                "git",
                "gcc",
                "libstdc++-12-dev",
            ]
        default:
            []
        }

        let manager: String? =
            switch platformName
        {
        case "ubuntu1804":
            "apt-get"
        case "ubuntu2004":
            "apt-get"
        case "ubuntu2204":
            "apt-get"
        case "ubuntu2404":
            "apt-get"
        case "amazonlinux2":
            "yum"
        case "ubi9":
            "yum"
        case "fedora39":
            "yum"
        case "debian12":
            "apt-get"
        default:
            nil
        }

        if requireSignatureValidation {
            guard (try? self.runProgram("gpg", "--version", quiet: true)) != nil else {
                var msg = "gpg is not installed. "
                if let manager {
                    msg += """
                    You can install it by running this command as root:
                        \(manager) -y install gpg
                    """
                } else {
                    msg += "you can install gpg to get signature verifications of the toolchahins."
                }
                msg += "\n" + Self.skipVerificationMessage

                throw SwiftlyError(message: msg)
            }

            let tmpFile = self.getTempFilePath()
            try await fs.create(.mode(0o600), file: tmpFile, contents: nil)
            try await fs.withTemporary(files: tmpFile) {
                try await ctx.httpClient.getGpgKeys().download(to: tmpFile)
                if let mockedHomeDir = ctx.mockedHomeDir {
                    var env = ProcessInfo.processInfo.environment
                    env["GNUPGHOME"] = (mockedHomeDir / ".gnupg").string
                    try await sys.gpg()._import(keys: tmpFile).run(self, env: env, quiet: true)
                } else {
                    try await sys.gpg()._import(keys: tmpFile).run(self, quiet: true)
                }
            }
        }

        guard let manager = manager else {
            return nil
        }

        var missingPackages: [String] = []

        for pkg in packages {
            if case let pkgInstalled = await self.isSystemPackageInstalled(manager, pkg), !pkgInstalled {
                missingPackages.append(pkg)
            }
        }

        guard !missingPackages.isEmpty else {
            return nil
        }

        return "\(manager) -y install \(missingPackages.joined(separator: " "))"
    }

    public func isSystemPackageInstalled(_ manager: String?, _ package: String) async -> Bool {
        do {
            switch manager {
            case "apt-get":
                if let pkgList = try await self.runProgramOutput("dpkg", "-l", package) {
                    // The package might be listed but not in an installed non-error state.
                    //
                    // Look for something like this:
                    //
                    //   Desired=Unknown/Install/Remove/Purge/Hold
                    //   | Status=Not/Inst/Conf-files/Unpacked/halF-conf/Half-inst/trig-aWait/Trig-pend
                    //   |/ Err?=(none)/Reinst-required (Status,Err: uppercase=bad)
                    //   ||/
                    //   ii  pkgfoo         1.0.0ubuntu12        My description goes here....
                    return pkgList.contains("\nii ")
                }
                return false
            case "yum":
                try self.runProgram("yum", "list", "installed", package, quiet: true)
                return true
            default:
                return true
            }
        } catch {
            return false
        }
    }

    public func install(
        _ ctx: SwiftlyCoreContext, from tmpFile: FilePath, version: ToolchainVersion, verbose: Bool
    ) async throws {
        guard try await fs.exists(atPath: tmpFile) else {
            throw SwiftlyError(message: "\(tmpFile) doesn't exist")
        }

        if !(try await fs.exists(atPath: self.swiftlyToolchainsDir(ctx))) {
            try await fs.mkdir(atPath: self.swiftlyToolchainsDir(ctx))
        }

        await ctx.print("Extracting toolchain...")
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
            await ctx.print("Extracting new swiftly...")
            try extractArchive(atPath: archive) { name in
                // Extract to the temporary directory
                tmpDir / String(name)
            }

            try self.runProgram((tmpDir / "swiftly").string, "init")
        }
    }

    public func uninstall(_ ctx: SwiftlyCoreContext, _ toolchain: ToolchainVersion, verbose _: Bool) async throws {
        let toolchainDir = self.swiftlyToolchainsDir(ctx) / toolchain.name
        try await fs.remove(atPath: toolchainDir)
    }

    public func getExecutableName() -> String {
        let arch = cpuArch

        return "swiftly-\(arch)-unknown-linux-gnu"
    }

    public func getTempFilePath() -> FilePath {
        fs.tmp / "swiftly-\(UUID())"
    }

    public func verifyToolchainSignature(
        _ ctx: SwiftlyCoreContext, toolchainFile: ToolchainFile, archive: FilePath, verbose: Bool
    ) async throws {
        if verbose {
            await ctx.print("Downloading toolchain signature...")
        }

        let sigFile = self.getTempFilePath()
        try await fs.create(file: sigFile, contents: nil)
        try await fs.withTemporary(files: sigFile) {
            try await ctx.httpClient.getSwiftToolchainFileSignature(toolchainFile).download(to: sigFile)

            await ctx.print("Verifying toolchain signature...")
            do {
                if let mockedHomeDir = ctx.mockedHomeDir {
                    var env = ProcessInfo.processInfo.environment
                    env["GNUPGHOME"] = (mockedHomeDir / ".gnupg").string
                    try await sys.gpg().verify(detachedSignature: sigFile, signedData: archive).run(self, env: env, quiet: false)
                } else {
                    try await sys.gpg().verify(detachedSignature: sigFile, signedData: archive).run(self, quiet: !verbose)
                }
            } catch {
                throw SwiftlyError(message: "Signature verification failed: \(error).")
            }
        }
    }

    public func verifySwiftlySignature(
        _ ctx: SwiftlyCoreContext, archiveDownloadURL: URL, archive: FilePath, verbose: Bool
    ) async throws {
        if verbose {
            await ctx.print("Downloading swiftly signature...")
        }

        let sigFile = self.getTempFilePath()
        try await fs.create(file: sigFile, contents: nil)
        try await fs.withTemporary(files: sigFile) {
            try await ctx.httpClient.getSwiftlyReleaseSignature(
                url: archiveDownloadURL.appendingPathExtension("sig")
            ).download(to: sigFile)

            await ctx.print("Verifying swiftly signature...")
            do {
                if let mockedHomeDir = ctx.mockedHomeDir {
                    var env = ProcessInfo.processInfo.environment
                    env["GNUPGHOME"] = (mockedHomeDir / ".gnupg").string
                    try await sys.gpg().verify(detachedSignature: sigFile, signedData: archive).run(self, env: env, quiet: false)
                } else {
                    try await sys.gpg().verify(detachedSignature: sigFile, signedData: archive).run(self, quiet: !verbose)
                }
            } catch {
                throw SwiftlyError(message: "Signature verification failed: \(error).")
            }
        }
    }

    private func manualSelectPlatform(_ ctx: SwiftlyCoreContext, _ platformPretty: String?) async
        -> PlatformDefinition
    {
        if let platformPretty {
            print(
                "\(platformPretty) is not an officially supported platform, but the toolchains for another platform may still work on it."
            )
        } else {
            print(
                "This platform could not be detected, but a toolchain for one of the supported platforms may work on it."
            )
        }

        let selections = self.linuxPlatforms.enumerated().map { "\($0 + 1)) \($1.namePretty)" }.joined(
            separator: "\n")

        print(
            """
            Please select the platform to use for toolchain downloads:

            0) Cancel
            \(selections)
            """)

        let choice =
            await ctx.readLine(prompt: "Pick one of the available selections [0-\(self.linuxPlatforms.count)] ")
                ?? "0"

        guard let choiceNum = Int(choice) else {
            fatalError("Installation canceled")
        }

        guard choiceNum > 0 && choiceNum <= self.linuxPlatforms.count else {
            fatalError("Installation canceled")
        }

        return self.linuxPlatforms[choiceNum - 1]
    }

    public func detectPlatform(
        _ ctx: SwiftlyCoreContext, disableConfirmation: Bool, platform: String?
    ) async throws -> PlatformDefinition {
        // We've been given a hint to use
        if let platform {
            guard let pd = linuxPlatforms.first(where: { $0.nameFull == platform }) else {
                fatalError(
                    "Unrecognized platform \(platform). Recognized values: \(self.linuxPlatforms.map(\.nameFull).joined(separator: ", "))."
                )
            }

            return pd
        }

        let osReleaseFiles = ["/etc/os-release", "/usr/lib/os-release"]
        var releaseFile: String?
        for file in osReleaseFiles {
            if try await fs.exists(atPath: FilePath(file)) {
                releaseFile = file
                break
            }
        }

        var platformPretty: String?

        guard let releaseFile = releaseFile else {
            let message = "Unable to detect the type of Linux OS and the release"
            if disableConfirmation {
                throw SwiftlyError(message: message)
            } else {
                print(message)
            }
            return await self.manualSelectPlatform(ctx, platformPretty)
        }

        let releaseInfo = try String(contentsOfFile: releaseFile, encoding: .utf8)

        var id: String?
        var idlike: String?
        var versionID: String?
        for info in releaseInfo.split(separator: "\n").map(String.init) {
            if info.hasPrefix("ID=") {
                id = String(info.dropFirst("ID=".count)).replacingOccurrences(of: "\"", with: "")
            } else if info.hasPrefix("ID_LIKE=") {
                idlike = String(info.dropFirst("ID_LIKE=".count)).replacingOccurrences(of: "\"", with: "")
            } else if info.hasPrefix("VERSION_ID=") {
                versionID = String(info.dropFirst("VERSION_ID=".count)).replacingOccurrences(
                    of: "\"", with: ""
                ).replacingOccurrences(of: ".", with: "")
            } else if info.hasPrefix("PRETTY_NAME=") {
                platformPretty = String(info.dropFirst("PRETTY_NAME=".count)).replacingOccurrences(
                    of: "\"", with: ""
                )
            }
        }

        guard let id, let versionID else {
            let message = "Unable to find release information from file \(releaseFile)"
            if disableConfirmation {
                throw SwiftlyError(message: message)
            } else {
                print(message)
            }
            return await self.manualSelectPlatform(ctx, platformPretty)
        }

        if (id + (idlike ?? "")).contains("amzn") {
            guard versionID == "2" else {
                let message = "Unsupported version of Amazon Linux"
                if disableConfirmation {
                    throw SwiftlyError(message: message)
                } else {
                    print(message)
                }
                return await self.manualSelectPlatform(ctx, platformPretty)
            }

            return .amazonlinux2
        } else if (id + (idlike ?? "")).contains("rhel") {
            guard versionID.hasPrefix("9") else {
                let message = "Unsupported version of RHEL"
                if disableConfirmation {
                    throw SwiftlyError(message: message)
                } else {
                    print(message)
                }
                return await self.manualSelectPlatform(ctx, platformPretty)
            }

            return .rhel9
        } else if let pd = [
            PlatformDefinition.ubuntu1804, .ubuntu2004, .ubuntu2204, .ubuntu2404, .debian12, .fedora39,
        ].first(where: { $0.name == id + versionID }) {
            return pd
        }

        let message = "Unsupported Linux platform"
        if disableConfirmation {
            throw SwiftlyError(message: message)
        } else {
            print(message)
        }
        return await self.manualSelectPlatform(ctx, platformPretty)
    }

    public func getShell() async throws -> String {
        let userName = ProcessInfo.processInfo.userName
        if let entry = try await sys.getent(database: "passwd", keys: userName).entries(self).first {
            if let shell = entry.last { return shell }
        }

        // Fall back on bash on Linux and other Unixes
        return "/bin/bash"
    }

    public func findToolchainLocation(_ ctx: SwiftlyCoreContext, _ toolchain: ToolchainVersion) -> FilePath
    {
        self.swiftlyToolchainsDir(ctx) / "\(toolchain.name)"
    }

    public static let currentPlatform: any Platform = Linux()
}
