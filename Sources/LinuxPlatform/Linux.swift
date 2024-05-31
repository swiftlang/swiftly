import Foundation
import SwiftlyCore

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

    public var toolchainFileExtension: String {
        "tar.gz"
    }

    public func isSystemDependencyPresent(_ dependency: SystemDependency) -> Bool {
        switch dependency {
        case .caCertificates:
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
                SwiftlyCore.print("The ca-certificates package is not installed. Swiftly won't be able to trust the sites to " +
                    "perform its downloads. Please install the ca-certificates package and try again.")
                return false
            }

            return true
        case .systemPackage(let package, let manager):
            do {
                switch manager {
                    case .apt:
                       try self.runProgram("dpkg", "-l", package, quiet: true)
                    case .yum:
                       try self.runProgram("yum", "list", "installed", package, quiet: true)
                    default:
                       break
                }
            } catch {
                return false
            }

            return true
        }
    }

    private static let skipVerificationMessage: String = "To skip signature verification, specify the --no-verify flag."

    public func verifySystemPrerequisitesForInstall(httpClient: SwiftlyHTTPClient, requireSignatureValidation: Bool) async throws {
        // The only prerequisite at the moment is that gpg is installed and the Swift project's keys have been imported.
        guard requireSignatureValidation else {
            return
        }

        guard (try? self.runProgram("gpg", "--version", quiet: true)) != nil else {
            throw Error(message: "gpg not installed, cannot perform signature verification. To set up gpg for " +
                "toolchain signature validation, follow the instructions at " +
                "https://www.swift.org/install/linux/#installation-via-tarball. " + Self.skipVerificationMessage)
        }

        let foundKeys = (try? self.runProgram(
            "gpg",
            "--list-keys",
            "swift-infrastructure@forums.swift.org",
            "swift-infrastructure@swift.org",
            quiet: true
        )) != nil

        if !foundKeys {
            SwiftlyCore.print("Importing Swift PGP keys...")
            let tmpFile = getTempFilePath()
            FileManager.default.createFile(atPath: tmpFile.path, contents: nil, attributes: [.posixPermissions: 0600])
            try await httpClient.downloadFile(
                url: URL(string: "https://swift.org/keys/all-keys.asc")!,
                to: tmpFile
            )

            do {
                try self.runProgram(
                    "gpg",
                    "--import",
                    tmpFile.path
                )
            } catch {
                throw Error(message: "Failed to import Swift PGP keys: \(error)")
            }
        }

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
    }

    public func install(from tmpFile: URL, version: ToolchainVersion) throws {
        guard tmpFile.fileExists() else {
            throw Error(message: "\(tmpFile) doesn't exist")
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

    public func listAvailableSnapshots(version _: String?) async -> [Snapshot] {
        []
    }

    public func getExecutableName() -> String {
        #if arch(x86_64)
        let architecture = "x86_64"
        #elseif arch(arm64)
        let architecture = "aarch64"
        #else
        fatalError("Unsupported processor architecture")
        #endif

        return "swiftly-\(architecture)-unknown-linux-gnu"
    }

    public func currentToolchain() throws -> ToolchainVersion? { nil }

    public func getTempFilePath() -> URL {
        let tmpFile = FileManager.default.temporaryDirectory.appendingPathComponent("swiftly-\(UUID())")
        return tmpFile
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
            throw Error(message: "Toolchain signature verification failed: \(error)")
        }
    }

    private func runProgram(_ args: String..., quiet: Bool = false) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = args

        if quiet {
            process.standardOutput = nil
            process.standardError = nil
        }

        try process.run()
        // Attach this process to our process group so that Ctrl-C and other signals work
        let pgid = tcgetpgrp(STDOUT_FILENO)
        if pgid != -1 {
            tcsetpgrp(STDOUT_FILENO, process.processIdentifier)
        }
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw Error(message: "\(args.first!) exited with non-zero status: \(process.terminationStatus)")
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
            switch(platform) {
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
            return manualSelectPlatform(platformPretty)
        }

        let data = FileManager.default.contents(atPath: releaseFile)
        guard let data = data else {
            let message = "Unable to read release information from file \(releaseFile)"
            if disableConfirmation {
                throw Error(message: message)
            } else {
                print(message)
            }
            return manualSelectPlatform(platformPretty)
        }

        guard let releaseInfo = String(data: data, encoding: .utf8) else {
            let message = "Unable to read release information from file \(releaseFile)"
            if disableConfirmation {
                throw Error(message: message)
            } else {
                print(message)
            }
            return manualSelectPlatform(platformPretty)
        }
 
        var id: String?
        var idlike: String?
        var versionID: String?
        var ubuntuCodeName: String?
        for info in releaseInfo.split(separator: "\n").map(String.init) {
            if info.hasPrefix("ID=") {
                id = String(info.dropFirst("ID=".count)).replacingOccurrences(of: "\"", with: "")
            } else if info.hasPrefix("ID_LIKE=") {
                idlike = String(info.dropFirst("ID_LINE=".count)).replacingOccurrences(of: "\"", with: "")
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
            return manualSelectPlatform(platformPretty)
        }

        if (id+idlike).contains("amzn") {
            guard let versionID = versionID, versionID == "2" else {
                let message = "Unsupported version of Amazon Linux"
                if disableConfirmation {
                    throw Error(message: message)
                } else {
                    print(message)
                }
                return manualSelectPlatform(platformPretty)
            }

            return PlatformDefinition(name: "amazonlinux2", nameFull: "amazonlinux2", namePretty: "Amazon Linux 2")
        } else if (id+idlike).contains("ubuntu") {
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
                return manualSelectPlatform(platformPretty)
            }
        } else if (id+idlike).contains("rhel") {
            guard let versionID = versionID, versionID.hasPrefix("9") else {
                let message = "Unsupported version of RHEL"
                if disableConfirmation {
                    throw Error(message: message)
                } else {
                    print(message)
                }
                return manualSelectPlatform(platformPretty)
            }

            return PlatformDefinition(name: "ubi9", nameFull: "ubi9", namePretty: "RHEL 9")
        }

        let message = "Unsupported Linux platform"
        if disableConfirmation {
            throw Error(message: message)
        } else {
            print(message)
        }
        return manualSelectPlatform(platformPretty)
    }

    /// Provide the command to install the provided system dependencies on the system
    public func getSysDepsCommand(with sysDeps: [SystemDependency], in platform: PlatformDefinition) -> String? {
        guard sysDeps.count != 0 else {
            return nil
        }

        let packages = sysDeps.map( { sysDep in
            switch sysDep {
            case .systemPackage(let name, _):
                name
            default:
                fatalError("Unexpected system dependency type \(sysDep)")
            }
        } ).joined(separator: " ")

        if ["ubuntu1804", "ubuntu2004", "ubuntu2204", "amazonlinux2"].contains(platform.name) {
            return "apt-get -y update && apt-get -y install \(packages)"
        } else if ["ubi9"].contains(platform.name) {
            return "yum -y install \(packages)"
        }

        return nil
    }

    public func proxy(_ toolchain: ToolchainVersion, _ command: String, _ arguments: [String]) async throws {
        let process = Process()
        process.executableURL = self.swiftlyToolchainsDir
            .appendingPathComponent(toolchain.name, isDirectory: true)
            .appendingPathComponent("usr/bin", isDirectory: true)
            .appendingPathComponent(command, isDirectory: false)
        process.arguments = arguments
        process.standardInput = FileHandle.standardInput

        try process.run()
        // Attach this process to our process group so that Ctrl-C and other signals work
        let pgid = tcgetpgrp(STDOUT_FILENO)
        if pgid != -1 {
            tcsetpgrp(STDOUT_FILENO, process.processIdentifier)
        }
        process.waitUntilExit()

        exit(process.terminationStatus)
    }

    public static let currentPlatform: any Platform = Linux()
}
