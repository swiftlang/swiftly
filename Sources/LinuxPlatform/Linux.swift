import Foundation
import SwiftlyCore

var swiftGPGKeysRefreshed = false

/// `Platform` implementation for Linux systems.
/// This implementation can be reused for any supported Linux platform.
/// TODO: replace dummy implementations
public struct Linux: Platform {
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

    public func verifySystemPrerequisitesForInstall(platformName: String, version _: ToolchainVersion, requireSignatureValidation: Bool) throws -> String? {
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
        default:
            []
        }

        let manager: String? = switch platformName {
        case "ubuntu1804":
            "apt"
        case "ubuntu2004":
            "apt"
        case "ubuntu2204":
            "apt"
        case "amazonlinux2":
            "yum"
        case "ubi9":
            "yum"
        default:
            nil
        }

        if requireSignatureValidation {
            guard (try? self.runProgram("gpg", "--version", quiet: true)) != nil else {
                var msg = "gpg is not installed. "
                if let manager = manager {
                    msg += """
                    you can install it by running this command as root:
                        \(manager) -y install gpg
                    """
                } else {
                    msg += "you can install gpg to get signature verifications of the toolchahins. "
                }
                msg += Self.skipVerificationMessage

                throw Error(message: msg)
            }

            let foundKeys = (try? self.runProgram(
                "gpg",
                "--list-keys",
                "swift-infrastructure@forums.swift.org",
                "swift-infrastructure@swift.org",
                quiet: true
            )) != nil
            guard foundKeys else {
                throw Error(message: "Swift PGP keys not imported, cannot perform signature verification. " +
                    "To enable verification, import the keys with the following command: " +
                    "'wget -q -O - https://swift.org/keys/all-keys.asc | gpg --import -' " +
                    Self.skipVerificationMessage)
            }

            // We only need to refresh the keys once per session, which will help with performance in tests
            if !swiftGPGKeysRefreshed {
                SwiftlyCore.print("Refreshing Swift PGP keys...")
                do {
                    try self.runProgram(
                        "gpg",
                        "--quiet",
                        "--keyserver",
                        "hkp://keyserver.ubuntu.com",
                        "--refresh-keys",
                        "Swift"
                    )
                } catch {
                    throw Error(message: "Failed to refresh PGP keys: \(error)")
                }
                swiftGPGKeysRefreshed = true
            }
        }

        guard let manager = manager else {
            return nil
        }

        let missingPackages = packages.filter { !self.isSystemPackageInstalled(manager, $0) }.joined(separator: " ")

        guard !missingPackages.isEmpty else {
            return nil
        }

        return "\(manager) -y install \(missingPackages)"
    }

    public func isSystemPackageInstalled(_ manager: String?, _ package: String) -> Bool {
        do {
            switch manager {
            case "apt":
                try self.runProgram("dpkg", "-l", package, quiet: true)
                return true
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
        FileManager.default.createFile(atPath: sigFile.path, contents: nil)
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
            throw Error(message: "Toolchain signature verification failed: \(error).")
        }
    }

    private func manualSelectPlatform(_ platformPretty: String?) -> PlatformDefinition {
        if let platformPretty = platformPretty {
            print("\(platformPretty) is not an officially supported platform, but the toolchains for another platform may still work on it.")
        } else {
            print("This platform could not be detected, but a toolchain for one of the supported platforms may work on it.")
        }

        print("""
        Please select the platform to use for toolchain downloads:

        0) Cancel
        1) Ubuntu 22.04
        2) Ubuntu 20.04
        3) Ubuntu 18.04
        4) RHEL 9
        5) Amazon Linux 2
        """)

        let choice = SwiftlyCore.readLine(prompt: "> ") ?? "0"

        switch choice {
        case "1":
            return PlatformDefinition(name: "ubuntu2204", nameFull: "ubuntu22.04", namePretty: "Ubuntu 22.04")
        case "2":
            return PlatformDefinition(name: "ubuntu2004", nameFull: "ubuntu20.04", namePretty: "Ubuntu 20.04")
        case "3":
            return PlatformDefinition(name: "ubuntu1804", nameFull: "ubuntu18.04", namePretty: "Ubuntu 18.04")
        case "4":
            return PlatformDefinition(name: "ubi9", nameFull: "ubi9", namePretty: "RHEL 9")
        case "5":
            return PlatformDefinition(name: "amazonlinux2", nameFull: "amazonlinux2", namePretty: "Amazon Linux 2")
        default:
            fatalError("Installation canceled")
        }
    }

    public func detectPlatform(disableConfirmation: Bool, platform: String?) async throws -> PlatformDefinition {
        // We've been given a hint to use
        if let platform = platform {
            switch platform {
            case "ubuntu22.04":
                return PlatformDefinition(name: "ubuntu2204", nameFull: "ubuntu22.04", namePretty: "Ubuntu 22.04")
            case "ubuntu20.04":
                return PlatformDefinition(name: "ubuntu2004", nameFull: "ubuntu20.04", namePretty: "Ubuntu 20.04")
            case "ubuntu18.04":
                return PlatformDefinition(name: "ubuntu1804", nameFull: "ubuntu18.04", namePretty: "Ubuntu 18.04")
            case "amazonlinux2":
                return PlatformDefinition(name: "amazonlinux2", nameFull: "amazonlinux2", namePretty: "Amazon Linux 2")
            case "rhel9":
                return PlatformDefinition(name: "ubi9", nameFull: "ubi9", namePretty: "RHEL 9")
            default:
                fatalError("Unrecognized platform \(platform)")
            }
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
            return self.manualSelectPlatform(platformPretty)
        }

        let data = FileManager.default.contents(atPath: releaseFile)
        guard let data = data else {
            let message = "Unable to read release information from file \(releaseFile)"
            if disableConfirmation {
                throw Error(message: message)
            } else {
                print(message)
            }
            return self.manualSelectPlatform(platformPretty)
        }

        guard let releaseInfo = String(data: data, encoding: .utf8) else {
            let message = "Unable to read release information from file \(releaseFile)"
            if disableConfirmation {
                throw Error(message: message)
            } else {
                print(message)
            }
            return self.manualSelectPlatform(platformPretty)
        }

        var id: String?
        var idlike: String?
        var versionID: String?
        var ubuntuCodeName: String?
        for info in releaseInfo.split(separator: "\n").map(String.init) {
            if info.hasPrefix("ID=") {
                id = String(info.dropFirst("ID=".count)).replacingOccurrences(of: "\"", with: "")
            } else if info.hasPrefix("ID_LIKE=") {
                idlike = String(info.dropFirst("ID_LIKE=".count)).replacingOccurrences(of: "\"", with: "")
            } else if info.hasPrefix("VERSION_ID=") {
                versionID = String(info.dropFirst("VERSION_ID=".count)).replacingOccurrences(of: "\"", with: "")
            } else if info.hasPrefix("UBUNTU_CODENAME=") {
                ubuntuCodeName = String(info.dropFirst("UBUNTU_CODENAME=".count)).replacingOccurrences(of: "\"", with: "")
            } else if info.hasPrefix("PRETTY_NAME=") {
                platformPretty = String(info.dropFirst("PRETTY_NAME=".count)).replacingOccurrences(of: "\"", with: "")
            }
        }

        guard let id = id, let idlike = idlike else {
            let message = "Unable to find release information from file \(releaseFile)"
            if disableConfirmation {
                throw Error(message: message)
            } else {
                print(message)
            }
            return self.manualSelectPlatform(platformPretty)
        }

        if (id + idlike).contains("amzn") {
            guard let versionID = versionID, versionID == "2" else {
                let message = "Unsupported version of Amazon Linux"
                if disableConfirmation {
                    throw Error(message: message)
                } else {
                    print(message)
                }
                return self.manualSelectPlatform(platformPretty)
            }

            return PlatformDefinition(name: "amazonlinux2", nameFull: "amazonlinux2", namePretty: "Amazon Linux 2")
        } else if (id + idlike).contains("ubuntu") {
            if ubuntuCodeName == "jammy" {
                return PlatformDefinition(name: "ubuntu2204", nameFull: "ubuntu22.04", namePretty: "Ubuntu 22.04")
            } else if ubuntuCodeName == "focal" {
                return PlatformDefinition(name: "ubuntu2004", nameFull: "ubuntu20.04", namePretty: "Ubuntu 20.04")
            } else if ubuntuCodeName == "bionic" {
                return PlatformDefinition(name: "ubuntu1804", nameFull: "ubuntu18.04", namePretty: "Ubuntu 18.04")
            } else {
                let message = "Unsupported version of Ubuntu Linux"
                if disableConfirmation {
                    throw Error(message: message)
                } else {
                    print(message)
                }
                return self.manualSelectPlatform(platformPretty)
            }
        } else if (id + idlike).contains("rhel") {
            guard let versionID = versionID, versionID.hasPrefix("9") else {
                let message = "Unsupported version of RHEL"
                if disableConfirmation {
                    throw Error(message: message)
                } else {
                    print(message)
                }
                return self.manualSelectPlatform(platformPretty)
            }

            return PlatformDefinition(name: "ubi9", nameFull: "ubi9", namePretty: "RHEL 9")
        }

        let message = "Unsupported Linux platform"
        if disableConfirmation {
            throw Error(message: message)
        } else {
            print(message)
        }
        return self.manualSelectPlatform(platformPretty)
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
