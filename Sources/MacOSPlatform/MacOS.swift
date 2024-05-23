import Foundation
import SwiftlyCore

struct SwiftPkgInfo: Codable {
    var CFBundleIdentifier: String
}

/// `Platform` implementation for macOS systems.
public struct MacOS: Platform {
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
        "pkg"
    }

    public func isSystemDependencyPresent(_: SystemDependency) -> Bool {
        // All system dependencies on macOS should be present
        true
    }

    public func verifySystemPrerequisitesForInstall(httpClient: SwiftlyHTTPClient, requireSignatureValidation: Bool) throws {
        // All system prerequisites should be there for macOS
    }

    public func install(from tmpFile: URL, version: ToolchainVersion) throws {
        guard tmpFile.fileExists() else {
            throw Error(message: "\(tmpFile) doesn't exist")
        }

        if !self.swiftlyToolchainsDir.fileExists() {
            try FileManager.default.createDirectory(at: self.swiftlyToolchainsDir, withIntermediateDirectories: false)
        }

        SwiftlyCore.print("Installing package in user home directory...")
        try runProgram("installer", "-pkg", tmpFile.path, "-target", "CurrentUserHomeDirectory")
    }

    public func uninstall(_ toolchain: ToolchainVersion) throws {
        SwiftlyCore.print("Uninstalling package in user home directory...")

        let toolchainDir = self.swiftlyToolchainsDir.appendingPathComponent("\(toolchain.identifier).xctoolchain", isDirectory: true)

        let decoder = PropertyListDecoder()
        let infoPlist = toolchainDir.appendingPathComponent("Info.plist")
        guard let data = try? Data(contentsOf: infoPlist) else {
            throw Error(message: "could not open \(infoPlist)")
        }

        guard let pkgInfo = try? decoder.decode(SwiftPkgInfo.self, from: data) else {
            throw Error(message: "could not decode plist at \(infoPlist)")
        }

        try FileManager.default.removeItem(at: toolchainDir)

        let homedir = ProcessInfo.processInfo.environment["HOME"]!
        try runProgram("pkgutil", "--volume", homedir, "--forget", pkgInfo.CFBundleIdentifier)
    }

    public func use(_ toolchain: ToolchainVersion, currentToolchain: ToolchainVersion?) throws -> Bool {
        let toolchainBinURL = self.swiftlyToolchainsDir
            .appendingPathComponent(toolchain.identifier + ".xctoolchain", isDirectory: true)
            .appendingPathComponent("usr", isDirectory: true)
            .appendingPathComponent("bin", isDirectory: true)

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

        SwiftlyCore.print("""
            NOTE: On macOS it is possible that the shell will pick up the system Swift on the path
            instead of the one that swiftly has installed for you. You can run the 'hash -r'
            command to update the shell with the latest PATHs.

                hash -r

            """
        )

        return true
    }

    public func unUse(currentToolchain: ToolchainVersion) throws {
        let currentToolchainBinURL = self.swiftlyToolchainsDir
            .appendingPathComponent(currentToolchain.identifier + ".xctoolchain", isDirectory: true)
            .appendingPathComponent("usr", isDirectory: true)
            .appendingPathComponent("bin", isDirectory: true)

        for existingExecutable in try FileManager.default.contentsOfDirectory(atPath: currentToolchainBinURL.path) {
            guard existingExecutable != "swiftly" else {
                continue
            }

            let url = self.swiftlyBinDir.appendingPathComponent(existingExecutable)
            let vals = try url.resourceValues(forKeys: [URLResourceKey.isSymbolicLinkKey])

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

    public func getExecutableName(forArch: String) -> String {
        "swiftly-\(forArch)-macos-osx"
    }

    public func currentToolchain() throws -> ToolchainVersion? { nil }

    public func getTempFilePath() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("swiftly-\(UUID()).pkg")
    }

    public func verifySignature(httpClient: SwiftlyHTTPClient, archiveDownloadURL: URL, archive: URL) async throws {
        // No signature verification is required on macOS since the pkg files have their own signing
        //  mechanism and the swift.org downloadables are trusted by stock macOS installations.
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
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw Error(message: "\(args.first!) exited with non-zero status: \(process.terminationStatus)")
        }
    }

    public func detectPlatform(disableConfirmation: Bool) async -> PlatformDefinition {
        // No special detection required on macOS platform
        return PlatformDefinition(name: "xcode", nameFull: "osx", namePretty: "macOS", architecture: Optional<String>.none)
    }

    public static let currentPlatform: any Platform = MacOS()
}
