import Foundation
import SwiftlyCore

var swiftGPGKeysRefreshed = false

/// `Platform` implementation for Linux systems.
/// This implementation can be reused for any supported Linux platform.
/// TODO: replace dummy implementations
public struct Linux: Platform {
    let linuxPlatforms = [
        PlatformDefinition.ubuntu2404,
        PlatformDefinition.ubuntu2204,
        PlatformDefinition.ubuntu2004,
        PlatformDefinition.ubuntu1804,
        PlatformDefinition.fedora39,
        PlatformDefinition.rhel9,
        PlatformDefinition.amazonlinux2,
        PlatformDefinition.debian12,
    ]

    public init() {}

    public var appDataDirectory: URL {
        if let dir = ProcessInfo.processInfo.environment["XDG_DATA_HOME"] {
            return URL(fileURLWithPath: dir)
        } else {
            return FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".local", isDirectory: true)
                .appendingPathComponent("share", isDirectory: true)
        }
    }

    public var swiftlyBinDir: URL {
        SwiftlyCore.mockedHomeDir.map { $0.appendingPathComponent("bin", isDirectory: true) }
            ?? ProcessInfo.processInfo.environment["SWIFTLY_BIN_DIR"].map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local", isDirectory: true)
            .appendingPathComponent("bin", isDirectory: true)
    }

    public var swiftlyToolchainsDir: URL {
        self.swiftlyHomeDir.appendingPathComponent("toolchains", isDirectory: true)
    }

    public var toolchainFileExtension: String {
        "tar.gz"
    }

    public func isSystemDependencyPresent(_: SystemDependency) -> Bool {
        true
    }

    private static let skipVerificationMessage: String = "To skip signature verification, specify the --no-verify flag."

    public func verifySwiftlySystemPrerequisites() throws {
        // Check if the root CA certificates are installed on this system for NIOSSL to use.
        // This list comes from LinuxCABundle.swift in NIOSSL.
        var foundTrustedCAs = false
        for crtFile in ["/etc/ssl/certs/ca-certificates.crt", "/etc/pki/tls/certs/ca-bundle.crt"] {
            if URL(fileURLWithPath: crtFile).fileExists() {
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

            throw Error(message: msg)
        }
    }

    public func verifySystemPrerequisitesForInstall(httpClient: SwiftlyHTTPClient, platformName: String, version _: ToolchainVersion, requireSignatureValidation: Bool) async throws -> String? {
        // TODO: these are hard-coded until we have a place to query for these based on the toolchain version
        // These lists were copied from the dockerfile sources here: https://github.com/apple/swift-docker/tree/ea035798755cce4ec41e0c6dbdd320904cef0421/5.10
        let packages: [String] = switch platformName {
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
                "libcurl-devel",
                "libedit",
                "libicu",
                "libuuid",
                "libxml2-devel",
                "sqlite-devel",
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
                "binutils-gold",
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

        let manager: String? = switch platformName {
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
                if let manager = manager {
                    msg += """
                    You can install it by running this command as root:
                        \(manager) -y install gpg
                    """
                } else {
                    msg += "you can install gpg to get signature verifications of the toolchahins."
                }
                msg += "\n" + Self.skipVerificationMessage

                throw Error(message: msg)
            }

            // Import the latest swift keys, but only once per session, which will help with the performance in tests
            if !swiftGPGKeysRefreshed {
                let tmpFile = self.getTempFilePath()
                let _ = FileManager.default.createFile(atPath: tmpFile.path, contents: nil, attributes: [.posixPermissions: 0o600])
                defer {
                    try? FileManager.default.removeItem(at: tmpFile)
                }

                guard let url = URL(string: "https://www.swift.org/keys/all-keys.asc") else {
                    throw Error(message: "malformed URL to the swift gpg keys")
                }

                try await httpClient.downloadFile(url: url, to: tmpFile)
                try self.runProgram("gpg", "--import", tmpFile.path, quiet: true)

                swiftGPGKeysRefreshed = true
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

    public func install(from tmpFile: URL, version: ToolchainVersion) throws {
        guard tmpFile.fileExists() else {
            throw Error(message: "\(tmpFile) doesn't exist")
        }

        if !self.swiftlyToolchainsDir.fileExists() {
            try FileManager.default.createDirectory(at: self.swiftlyToolchainsDir, withIntermediateDirectories: false)
        }

        SwiftlyCore.print("Extracting toolchain...")
        let toolchainDir = self.swiftlyToolchainsDir.appendingPathComponent(version.name)

        if toolchainDir.fileExists() {
            try FileManager.default.removeItem(at: toolchainDir)
        }

        try extractArchive(atPath: tmpFile) { name in
            // drop swift-a.b.c-RELEASE etc name from the extracted files.
            let relativePath = name.drop { c in c != "/" }.dropFirst()

            // prepend /path/to/swiftlyHomeDir/toolchains/<toolchain> to each file name
            return toolchainDir.appendingPathComponent(String(relativePath))
        }
    }

    public func extractSwiftlyAndInstall(from archive: URL) throws {
        guard archive.fileExists() else {
            throw Error(message: "\(archive) doesn't exist")
        }

        let tmpDir = self.getTempFilePath()
        try FileManager.default.createDirectory(atPath: tmpDir.path, withIntermediateDirectories: true)

        SwiftlyCore.print("Extracting new swiftly...")
        try extractArchive(atPath: archive) { name in
            // Extract to the temporary directory
            tmpDir.appendingPathComponent(String(name))
        }

        try self.runProgram(tmpDir.appendingPathComponent("swiftly").path, "init")
    }

    public func uninstall(_ toolchain: ToolchainVersion) throws {
        let toolchainDir = self.swiftlyToolchainsDir.appendingPathComponent(toolchain.name)
        try FileManager.default.removeItem(at: toolchainDir)
    }

    public func use(_ toolchain: ToolchainVersion, currentToolchain: ToolchainVersion?) throws -> Bool {
        let toolchainBinURL = self.swiftlyToolchainsDir
            .appendingPathComponent(toolchain.name, isDirectory: true)
            .appendingPathComponent("usr", isDirectory: true)
            .appendingPathComponent("bin", isDirectory: true)

        if !FileManager.default.fileExists(atPath: toolchainBinURL.path) {
            return false
        }

        // Delete existing symlinks from previously in-use toolchain.
        if let currentToolchain {
            try self.unUse(currentToolchain: currentToolchain)
        }

        // Ensure swiftly doesn't overwrite any existing executables without getting confirmation first.
        let swiftlyBinDirContents = try FileManager.default.contentsOfDirectory(atPath: self.swiftlyBinDir.path)
        let toolchainBinDirContents = try FileManager.default.contentsOfDirectory(atPath: toolchainBinURL.path)
        let willBeOverwritten = Set(toolchainBinDirContents).intersection(swiftlyBinDirContents)
        if !willBeOverwritten.isEmpty {
            SwiftlyCore.print("The following existing executables will be overwritten:")

            for executable in willBeOverwritten {
                SwiftlyCore.print("  \(self.swiftlyBinDir.appendingPathComponent(executable).path)")
            }

            let proceed = SwiftlyCore.readLine(prompt: "Proceed? (y/n)") ?? "n"

            guard proceed == "y" else {
                SwiftlyCore.print("Aborting use")
                return false
            }
        }

        for executable in toolchainBinDirContents {
            let linkURL = self.swiftlyBinDir.appendingPathComponent(executable)
            let executableURL = toolchainBinURL.appendingPathComponent(executable)

            // Deletion confirmed with user above.
            try linkURL.deleteIfExists()

            try FileManager.default.createSymbolicLink(
                atPath: linkURL.path,
                withDestinationPath: executableURL.path
            )
        }

        return true
    }

    public func unUse(currentToolchain: ToolchainVersion) throws {
        let currentToolchainBinURL = self.swiftlyToolchainsDir
            .appendingPathComponent(currentToolchain.name, isDirectory: true)
            .appendingPathComponent("usr", isDirectory: true)
            .appendingPathComponent("bin", isDirectory: true)

        for existingExecutable in try FileManager.default.contentsOfDirectory(atPath: currentToolchainBinURL.path) {
            guard existingExecutable != "swiftly" else {
                continue
            }

            let url = self.swiftlyBinDir.appendingPathComponent(existingExecutable)
            let vals = try url.resourceValues(forKeys: [.isSymbolicLinkKey])

            guard let islink = vals.isSymbolicLink, islink else {
                throw Error(message: "Found executable not managed by swiftly in SWIFTLY_BIN_DIR: \(url.path)")
            }
            let symlinkDest = url.resolvingSymlinksInPath()
            guard symlinkDest.deletingLastPathComponent() == currentToolchainBinURL else {
                throw Error(message: "Found symlink that points to non-swiftly managed executable: \(symlinkDest.path)")
            }

            try self.swiftlyBinDir.appendingPathComponent(existingExecutable).deleteIfExists()
        }
    }

    public func listAvailableSnapshots(version _: String?) async -> [Snapshot] {
        []
    }

    public func getExecutableName() -> String {
#if arch(x86_64)
        let arch = "x86_64"
#elseif arch(arm64)
        let arch = "aarch64"
#else
        fatalError("Unsupported processor architecture")
#endif

        return "swiftly-\(arch)-unknown-linux-gnu"
    }

    public func currentToolchain() throws -> ToolchainVersion? { nil }

    public func getTempFilePath() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("swiftly-\(UUID())")
    }

    public func verifySignature(httpClient: SwiftlyHTTPClient, archiveDownloadURL: URL, archive: URL) async throws {
        SwiftlyCore.print("Downloading toolchain signature...")
        let sigFile = self.getTempFilePath()
        let _ = FileManager.default.createFile(atPath: sigFile.path, contents: nil)
        defer {
            try? FileManager.default.removeItem(at: sigFile)
        }

        try await httpClient.downloadFile(
            url: archiveDownloadURL.appendingPathExtension("sig"),
            to: sigFile
        )

        SwiftlyCore.print("Verifying toolchain signature...")
        do {
            try self.runProgram("gpg", "--verify", sigFile.path, archive.path)
        } catch {
            throw Error(message: "Signature verification failed: \(error).")
        }
    }

    private func manualSelectPlatform(_ platformPretty: String?) async -> PlatformDefinition {
        if let platformPretty = platformPretty {
            print("\(platformPretty) is not an officially supported platform, but the toolchains for another platform may still work on it.")
        } else {
            print("This platform could not be detected, but a toolchain for one of the supported platforms may work on it.")
        }

        let selections = self.linuxPlatforms.enumerated().map { "\($0 + 1)) \($1.namePretty)" }.joined(separator: "\n")

        print("""
        Please select the platform to use for toolchain downloads:

        0) Cancel
        \(selections)
        """)

        let choice = SwiftlyCore.readLine(prompt: "Pick one of the available selections [0-\(self.linuxPlatforms.count)] ") ?? "0"

        guard let choiceNum = Int(choice) else {
            fatalError("Installation canceled")
        }

        guard choiceNum > 0 && choiceNum <= self.linuxPlatforms.count else {
            fatalError("Installation canceled")
        }

        return self.linuxPlatforms[choiceNum - 1]
    }

    public func detectPlatform(disableConfirmation: Bool, platform: String?) async throws -> PlatformDefinition {
        // We've been given a hint to use
        if let platform {
            guard let pd = linuxPlatforms.first(where: { $0.nameFull == platform }) else {
                fatalError("Unrecognized platform \(platform). Recognized values: \(self.linuxPlatforms.map(\.nameFull).joined(separator: ", ")).")
            }

            return pd
        }

        let osReleaseFiles = ["/etc/os-release", "/usr/lib/os-release"]
        var releaseFile: String?
        for file in osReleaseFiles {
            if FileManager.default.fileExists(atPath: file) {
                releaseFile = file
                break
            }
        }

        var platformPretty: String?

        guard let releaseFile = releaseFile else {
            let message = "Unable to detect the type of Linux OS and the release"
            if disableConfirmation {
                throw Error(message: message)
            } else {
                print(message)
            }
            return await self.manualSelectPlatform(platformPretty)
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
                versionID = String(info.dropFirst("VERSION_ID=".count)).replacingOccurrences(of: "\"", with: "").replacingOccurrences(of: ".", with: "")
            } else if info.hasPrefix("PRETTY_NAME=") {
                platformPretty = String(info.dropFirst("PRETTY_NAME=".count)).replacingOccurrences(of: "\"", with: "")
            }
        }

        guard let id, let versionID else {
            let message = "Unable to find release information from file \(releaseFile)"
            if disableConfirmation {
                throw Error(message: message)
            } else {
                print(message)
            }
            return await self.manualSelectPlatform(platformPretty)
        }

        if (id + (idlike ?? "")).contains("amzn") {
            guard versionID == "2" else {
                let message = "Unsupported version of Amazon Linux"
                if disableConfirmation {
                    throw Error(message: message)
                } else {
                    print(message)
                }
                return await self.manualSelectPlatform(platformPretty)
            }

            return PlatformDefinition.amazonlinux2
        } else if (id + (idlike ?? "")).contains("rhel") {
            guard versionID.hasPrefix("9") else {
                let message = "Unsupported version of RHEL"
                if disableConfirmation {
                    throw Error(message: message)
                } else {
                    print(message)
                }
                return await self.manualSelectPlatform(platformPretty)
            }

            return PlatformDefinition.rhel9
        } else if let pd = [PlatformDefinition.ubuntu1804, .ubuntu2004, .ubuntu2204, .ubuntu2404, .debian12, .fedora39].first(where: { $0.name == id + versionID }) {
            return pd
        }

        let message = "Unsupported Linux platform"
        if disableConfirmation {
            throw Error(message: message)
        } else {
            print(message)
        }
        return await self.manualSelectPlatform(platformPretty)
    }

    public func getShell() async throws -> String {
        if let passwds = try await runProgramOutput("getent", "passwd") {
            for line in passwds.components(separatedBy: "\n") {
                if line.hasPrefix("root:") {
                    if case let comps = line.components(separatedBy: ":"), comps.count > 1 {
                        return comps[comps.count - 1]
                    }
                }
            }
        }

        // Fall back on bash on Linux and other Unixes
        return "/bin/bash"
    }

    public static let currentPlatform: any Platform = Linux()
}
