import ArgumentParser
import SwiftlyCore
import Foundation

func findSwiftVersionFile() -> (file: URL, selector: ToolchainSelector)? {
    var cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

    while true {
        guard FileManager.default.fileExists(atPath: cwd.path) else {
            break
        }

        let svFile = cwd.appendingPathComponent(".swift-version", isDirectory: false)

        if FileManager.default.fileExists(atPath: svFile.path) {
            do {
                let contents = try String(contentsOf: svFile, encoding: .utf8)
                if !contents.isEmpty {
                    do {
                        let selector = try ToolchainSelector(parsing: contents.replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: "\r", with: ""))
                        return (svFile, selector)
                    } catch {}
                }
            } catch {}
        }

        cwd = cwd.deletingLastPathComponent()
    }

    return nil
}

private func findCurrentSwiftPackageLocation() -> URL? {
    var cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

    while true {
        guard FileManager.default.fileExists(atPath: cwd.path) else {
            break
        }

        let svFile = cwd.appendingPathComponent("Package.swift", isDirectory: false)

        if FileManager.default.fileExists(atPath: svFile.path) {
            return cwd
        }

        cwd = cwd.deletingLastPathComponent()
    }

    return nil
}

internal struct Use: SwiftlyCommand {
    public static var configuration = CommandConfiguration(
        abstract: "Set the active toolchain. If no toolchain is provided, print the currently in-use toolchain, if any."
    )

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

    @OptionGroup var root: GlobalOptions

    @Flag(name: .shortAndLong, help: "Update the global default toolchain setting without updating any local .swift-version file.")
    var globalDefault: Bool = false

    internal mutating func run() async throws {
        // First, validate the installation of swiftly
        var config = try await validate(root)

        guard let toolchain = self.toolchain else {
            if let (file, selector) = findSwiftVersionFile(), !globalDefault {
                SwiftlyCore.print("\(selector) (selected by \(file.path))")
            } else if let inUse = config.inUse {
                SwiftlyCore.print("\(inUse) (default)")
            }
            return
        }

        let selector = try ToolchainSelector(parsing: toolchain)

        guard let toolchain = config.listInstalledToolchains(selector: selector).max() else {
            SwiftlyCore.print("No installed toolchains match \"\(toolchain)\"")
            return
        }

        try await Self.execute(toolchain, &config, globalDefault: globalDefault)
    }

    /// Use a toolchain. This method modifies and saves the input config.
    internal static func execute(_ toolchain: ToolchainVersion, _ config: inout Config, globalDefault: Bool) async throws {
        if let (file, selector) = findSwiftVersionFile(), !globalDefault {
            guard toolchain.name != selector.description else {
                SwiftlyCore.print("\(toolchain) is already in use")
                return
            }

            try Data(toolchain.name.utf8).write(to: file, options: .atomic)

            SwiftlyCore.print("Set the active toolchain selector to \(toolchain) in \(file.path) (was \(selector.description))")
        } else if let swiftPackageLoc = findCurrentSwiftPackageLocation(), !globalDefault {
            let swiftVersionFile = swiftPackageLoc.appendingPathComponent(".swift-version", isDirectory: false)

            try Data(toolchain.name.utf8).write(to: swiftVersionFile, options: .atomic)

            SwiftlyCore.print("Set the selected toolchain to \(toolchain) in \(swiftVersionFile.path)")
        } else {
            let previousToolchain = config.inUse

            guard toolchain != previousToolchain else {
                SwiftlyCore.print("\(toolchain) is already in use")
                return
            }

            config.inUse = toolchain
            try config.save()

            let was = if let previousToolchain {
                " (was \(previousToolchain))"
            } else {
                ""
            }

            SwiftlyCore.print("Set the global default toolchain to \(toolchain)\(was)")
        }
    }
}
