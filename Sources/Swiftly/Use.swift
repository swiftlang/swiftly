import ArgumentParser
import Foundation
import SwiftlyCore

internal struct Use: SwiftlyCommand {
    public static var configuration = CommandConfiguration(
        abstract: "Set the active toolchain. If no toolchain is provided, print the currently in-use toolchain, if any."
    )

    @Flag(name: .shortAndLong, help: "Print the location of the in-use toolchain. This is valid only when there is no toolchain argument.")
    var printLocation: Bool = false

    @Flag(name: .shortAndLong, help: "Use the global default, ignoring any .swift-version files.")
    var globalDefault: Bool = false

    @Argument(help: ArgumentHelp(
        "The toolchain to use.",
        discussion: """

        If no toolchain is provided, the currently in-use toolchain will be printed, if any:

            $ swiftly use

        The string "latest" can be provided to use the most recent stable version release:

            $ swiftly use latest

        A specific toolchain can be selected by providing a full toolchain name, for example \
        a stable release version with patch (e.g. a.b.c):

            $ swiftly use 5.4.2

        Or a snapshot with date:

            $ swiftly use 5.7-snapshot-2022-06-20
            $ swiftly use main-snapshot-2022-06-20

        The latest patch release of a specific minor version can be used by omitting the \
        patch version:

            $ swiftly use 5.6

        Likewise, the latest snapshot associated with a given development branch can be \
        used by omitting the date:

            $ swiftly use 5.7-snapshot
            $ swiftly use main-snapshot
        """
    ))
    var toolchain: String?

    internal mutating func run() async throws {
        try validateSwiftly()
        var config = try Config.load()

        // This is the bare use command where we print the selected toolchain version (or the path to it)
        guard let toolchain = self.toolchain else {
            let (selectedVersion, result) = try await selectToolchain(config: &config, globalDefault: self.globalDefault)

            // Abort on any errors with the swift version files
            if case let .swiftVersionFile(_, error) = result, let error = error {
                throw error
            }

            guard let selectedVersion = selectedVersion else {
                // Return with nothing if there's no toolchain that is selected
                return
            }

            if self.printLocation {
                // Print the toolchain location and exit
                SwiftlyCore.print("\(Swiftly.currentPlatform.findToolchainLocation(selectedVersion).path)")
                return
            }

            var message = "\(selectedVersion)"

            switch result {
            case let .swiftVersionFile(versionFile, _):
                message += " (\(versionFile.path))"
            case .globalDefault:
                message += " (default)"
            }

            SwiftlyCore.print(message)

            return
        }

        guard !self.printLocation else {
            throw Error(message: "The print location flag cannot be used with a toolchain version.")
        }

        let selector = try ToolchainSelector(parsing: toolchain)

        guard let toolchain = config.listInstalledToolchains(selector: selector).max() else {
            SwiftlyCore.print("No installed toolchains match \"\(toolchain)\"")
            return
        }

        try await Self.execute(toolchain, self.globalDefault, &config)
    }

    /// Use a toolchain. This method can modify and save the input config.
    internal static func execute(_ toolchain: ToolchainVersion, _ globalDefault: Bool, _ config: inout Config) async throws {
        let (selectedVersion, result) = try await selectToolchain(config: &config, globalDefault: globalDefault)

        if let selectedVersion = selectedVersion {
            guard selectedVersion != toolchain else {
                SwiftlyCore.print("\(toolchain) is already in use")
                return
            }
        }

        if case let .swiftVersionFile(versionFile, _) = result {
            // We don't care in this case if there were any problems with the swift version files, just overwrite it with the new value
            try toolchain.name.write(to: versionFile, atomically: true, encoding: .utf8)
        } else if let newVersionFile = findNewVersionFile(), !globalDefault {
            try toolchain.name.write(to: newVersionFile, atomically: true, encoding: .utf8)
        } else {
            config.inUse = toolchain
            try config.save()
        }

        var message = "Set the used toolchain to \(toolchain)"
        if let selectedVersion = selectedVersion {
            message += " (was \(selectedVersion.name))"
        }

        SwiftlyCore.print(message)
    }

    internal static func findNewVersionFile() -> URL? {
        var cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

        while cwd.path != "" && cwd.path != "/" {
            guard FileManager.default.fileExists(atPath: cwd.path) else {
                break
            }

            let gitDir = cwd.appendingPathComponent(".git")

            if FileManager.default.fileExists(atPath: gitDir.path) {
                return cwd.appendingPathComponent(".swift-version")
            }

            cwd = cwd.deletingLastPathComponent()
        }

        return nil
    }
}

public enum ToolchainSelectionResult {
    case globalDefault
    case swiftVersionFile(URL, Error?)
}

/// Returns the currently selected swift toolchain, if any, with details of the selection.
///
/// The first portion of the returned tuple is the version that was selected, which
/// can be nil if none can be selected.
///
/// Selection of a toolchain can be accomplished in a number of ways. There is the
/// the configuration's global default 'inUse' setting. This is the fallback selector
/// if there are no other selections. The returned tuple will contain the default toolchain
/// version and the result will be .default.
///
/// A toolchain can also be selected from a `.swift-version` file in the current
/// working directory, or an ancestor directory. If it successfully selects a toolchain
/// then the result will be .swiftVersionFile with the URL of the file that made the
/// selection and the first item of the tuple is the selected toolchain version.
///
/// However, there are cases where the swift version file fails to select a toolchain.
/// If such a case happens then the toolchain version in the tuple will be nil, but the
/// result will be .swiftVersionFile and a detailed error about the problem. This error
/// can be thrown by the client, or ignored.
public func selectToolchain(config: inout Config, globalDefault: Bool = false, install: Bool = false) async throws -> (ToolchainVersion?, ToolchainSelectionResult) {
    if !globalDefault {
        var cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

        while cwd.path != "" && cwd.path != "/" {
            guard FileManager.default.fileExists(atPath: cwd.path) else {
                break
            }

            let svFile = cwd.appendingPathComponent(".swift-version")

            if FileManager.default.fileExists(atPath: svFile.path) {
                let contents = try? String(contentsOf: svFile, encoding: .utf8)

                guard let contents = contents else {
                    return (nil, .swiftVersionFile(svFile, Error(message: "The swift version file could not be read: \(svFile)")))
                }

                guard !contents.isEmpty else {
                    return (nil, .swiftVersionFile(svFile, Error(message: "The swift version file is empty: \(svFile)")))
                }

                let selectorString = contents.replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: "\r", with: "")
                let selector: ToolchainSelector?
                do {
                    selector = try ToolchainSelector(parsing: selectorString)
                } catch {
                    return (nil, .swiftVersionFile(svFile, Error(message: "The swift version file is malformed: \(svFile) \(error)")))
                }

                guard let selector = selector else {
                    return (nil, .swiftVersionFile(svFile, Error(message: "The swift version file is malformed: \(svFile)")))
                }

                if install {
                    let version = try await Install.resolve(config: config, selector: selector)
                    let postInstallScript = try await Install.execute(version: version, &config, useInstalledToolchain: false, verifySignature: true)
                    if let postInstallScript = postInstallScript {
                        throw Error(message: """

                        There are some system dependencies that should be installed before using this toolchain.
                        You can run the following script as the system administrator (e.g. root) to prepare
                        your system:

                        \(postInstallScript)
                        """)
                    }
                }

                guard let selectedToolchain = config.listInstalledToolchains(selector: selector).max() else {
                    return (nil, .swiftVersionFile(svFile, Error(message: "The swift version file didn't select any of the installed toolchains. You can install one with `swiftly install \(selector.description)`.")))
                }

                return (selectedToolchain, .swiftVersionFile(svFile, nil))
            }

            cwd = cwd.deletingLastPathComponent()
        }
    }

    return (config.inUse, .globalDefault)
}
