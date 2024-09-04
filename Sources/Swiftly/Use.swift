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
            let selected = try swiftToolchainSelection(config: config, globalDefault: self.globalDefault)

            guard let selected = selected else {
                // No toolchain selected, so we just output nothing
                return
            }

            let (selectedVersion, versionFile, selector) = selected

            if let versionFile = versionFile, selector == nil {
                throw Error(message: "Swift version file is malformed and cannot be used to select a swift toolchain: \(versionFile)")
            }

            guard let selectedVersion = selectedVersion else {
                fatalError("error in toolchain selection logic")
            }

            if self.printLocation {
                // Print the toolchain location and exit
                SwiftlyCore.print("\(Swiftly.currentPlatform.findToolchainLocation(selectedVersion).path)")
                return
            }

            if let versionFile = versionFile {
                SwiftlyCore.print("\(selectedVersion) (\(versionFile.path))")
            } else {
                SwiftlyCore.print("\(selectedVersion) (default)")
            }

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
        let previousToolchain = try swiftToolchainSelection(config: config, globalDefault: globalDefault)

        if let (selectedVersion, _, _) = previousToolchain {
            guard selectedVersion != toolchain else {
                SwiftlyCore.print("\(toolchain) is already in use")
                return
            }
        }

        if let (_, versionFile, _) = previousToolchain, let versionFile = versionFile {
            try toolchain.name.write(to: versionFile, atomically: true, encoding: .utf8)
        } else if let newVersionFile = findNewVersionFile(), !globalDefault {
            try toolchain.name.write(to: newVersionFile, atomically: true, encoding: .utf8)
        } else {
            config.inUse = toolchain
            try config.save()
        }

        var message = "Set the used toolchain to \(toolchain)"
        if let (selectedVersion, _, _) = previousToolchain,
           let selectedVersion = selectedVersion
        {
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

/// Returns the currently selected swift toolchain with optional details.
///
/// Selection of a toolchain can be accomplished in a number of ways. There is the
/// the configuration's global default 'inUse' setting. This is the fallback selector
/// if there are no other selections. In this case the returned tuple will contain
/// only the selected toolchain version. None of the other values are provided.
///
/// A toolchain can also be selected from a `.swift-version` file in the current
/// working directory, or an ancestor directory. The nearest version file is
/// returned as a URL if it is present, even if the file is malformed or it
/// doesn't select any of the installed toolchains. A well-formed version file
/// will additionally return the toolchain selector that it represents. Finally,
/// if that selector selects one of the installed toolchains then all three
/// values are returned.
///
/// Note: if no swift version files are found at all then the return will be nil
///
public func swiftToolchainSelection(config: Config, globalDefault: Bool = false) throws -> (ToolchainVersion?, URL?, ToolchainSelector?)? {
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
                    return (nil, svFile, nil)
                }

                guard !contents.isEmpty else {
                    return (nil, svFile, nil)
                }

                let selectorString = contents.replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: "\r", with: "")
                let selector: ToolchainSelector?
                do {
                    selector = try ToolchainSelector(parsing: selectorString)
                } catch {
                    return (nil, svFile, nil)
                }

                guard let selector = selector else {
                    return (nil, svFile, nil)
                }

                guard let selectedToolchain = config.listInstalledToolchains(selector: selector).max() else {
                    return (nil, svFile, selector)
                }

                return (selectedToolchain, svFile, selector)
            }

            cwd = cwd.deletingLastPathComponent()
        }
    }

    if let inUse = config.inUse {
        return (inUse, nil, nil)
    }

    return nil
}
