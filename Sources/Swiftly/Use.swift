import ArgumentParser
import Foundation
import SwiftlyCore
import SystemPackage

struct Use: SwiftlyCommand {
    public static let configuration = CommandConfiguration(
        abstract: "Set the in-use or default toolchain. If no toolchain is provided, print the currently in-use toolchain, if any."
    )

    @Flag(name: .shortAndLong, help: "Print the location of the in-use toolchain. This is valid only when there is no toolchain argument.")
    var printLocation: Bool = false

    @Flag(name: .shortAndLong, help: "Set the global default toolchain that is used when there are no .swift-version files.")
    var globalDefault: Bool = false

    @Option(name: .long, help: "Output format (text, json)")
    var format: SwiftlyCore.OutputFormat = .text

    @OptionGroup var root: GlobalOptions

    @Argument(help: ArgumentHelp(
        "The toolchain to use.",
        discussion: """

        If no toolchain is provided, the currently in-use toolchain will be printed, if any. \
        This is based on the current working directory and `.swift-version` files if one is \
        present. If the in-use toolchain is also the global default then it will be shown as \
        the default.

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

        macOS ONLY: There is a special selector for swiftly to use your Xcode toolchain. \
        If there are multiple versions of Xcode then swiftly will use the currently selected \
        toolchain from xcode-select.

            $ swiftly use xcode
        """
    ))
    var toolchain: String?

    mutating func run() async throws {
        try await self.run(Swiftly.createDefaultContext(format: self.format))
    }

    mutating func run(_ ctx: SwiftlyCoreContext) async throws {
        let versionUpdateReminder = try await validateSwiftly(ctx)
        defer {
            versionUpdateReminder()
        }

        var config = try await Config.load(ctx)

        try await validateLinked(ctx)

        // This is the bare use command where we print the selected toolchain version (or the path to it)
        guard let toolchain = self.toolchain else {
            let (selectedVersion, result) = try await selectToolchain(ctx, config: &config, globalDefault: self.globalDefault)

            // Abort on any errors with the swift version files
            if case let .swiftVersionFile(_, _, error) = result, let error {
                throw error
            }

            guard let selectedVersion else {
                // Return with nothing if there's no toolchain that is selected
                return
            }

            if self.printLocation {
                let location = LocationInfo(path: "\(try await Swiftly.currentPlatform.findToolchainLocation(ctx, selectedVersion))")
                try await ctx.output(location)
                return
            }

            let source: ToolchainSource? = switch result {
            case let .swiftVersionFile(versionFile, _, _):
                .swiftVersionFile("\(versionFile)")
            case .globalDefault:
                .globalDefault
            }

            let toolchainInfo = ToolchainInfo(version: selectedVersion, source: source)
            try await ctx.output(toolchainInfo)

            return
        }

        guard !self.printLocation else {
            throw SwiftlyError(message: "The print location flag cannot be used with a toolchain version.")
        }

        let selector = try ToolchainSelector(parsing: toolchain)

        guard let toolchain = config.listInstalledToolchains(selector: selector).max() else {
            throw SwiftlyError(message: "No installed toolchains match \"\(toolchain)\"")
        }

        let pathChanged = try await Self.execute(ctx, toolchain, globalDefault: self.globalDefault, verbose: self.root.verbose, assumeYes: self.root.assumeYes, &config)
        if pathChanged {
            try await Self.handlePathChange(ctx)
        }
    }

    /// Use a toolchain. This method can modify and save the input config and also create/modify a `.swift-version` file.
    static func execute(_ ctx: SwiftlyCoreContext, _ toolchain: ToolchainVersion, globalDefault: Bool, verbose: Bool, assumeYes: Bool = true, _ config: inout Config) async throws -> Bool {
        let (selectedVersion, result) = try await selectToolchain(ctx, config: &config, globalDefault: globalDefault)

        let isGlobal: Bool
        let configFile: String?

        if case let .swiftVersionFile(versionFile, _, _) = result {
            // We don't care in this case if there were any problems with the swift version files, just overwrite it with the new value
            try toolchain.name.write(to: versionFile, atomically: true)
            isGlobal = false
            configFile = "\(versionFile)"
        } else if let newVersionFile = try await findNewVersionFile(ctx), !globalDefault {
            if !assumeYes {
                await ctx.message("A new file `\(newVersionFile)` will be created to set the new in-use toolchain for this project. Alternatively, you can set your default globally with the `--global-default` flag. Proceed with creating this file?")

                guard await ctx.promptForConfirmation(defaultBehavior: true) else {
                    await ctx.message("Aborting setting in-use toolchain")
                    return false
                }
            }

            try toolchain.name.write(to: newVersionFile, atomically: true)
            isGlobal = false
            configFile = "\(newVersionFile)"
        } else {
            config.inUse = toolchain
            try config.save(ctx)
            isGlobal = true
            configFile = nil
        }

        let pathChanged = try await Install.setupProxies(
            ctx,
            version: toolchain,
            verbose: verbose,
            assumeYes: assumeYes
        )

        try await ctx.output(ToolchainSetInfo(
            version: toolchain,
            previousVersion: selectedVersion,
            isGlobal: isGlobal,
            versionFile: configFile
        ))

        return pathChanged
    }

    static func findNewVersionFile(_ ctx: SwiftlyCoreContext) async throws -> FilePath? {
        var cwd = ctx.currentDirectory

        while !cwd.isEmpty && !cwd.removingRoot().isEmpty {
            guard try await fs.exists(atPath: cwd) else {
                break
            }

            let gitDir = cwd / ".git"

            if try await fs.exists(atPath: gitDir) {
                return cwd / ".swift-version"
            }

            cwd = cwd.removingLastComponent()
        }

        return nil
    }
}

public enum ToolchainSelectionResult: Sendable {
    case globalDefault
    case swiftVersionFile(FilePath, ToolchainSelector?, Error?)
}

/// Returns the currently selected swift toolchain, if any, with details of the selection.
///
/// The first portion of the returned tuple is the version that was selected, which
/// can be nil if none can be selected.
///
/// Selection of a toolchain can be accomplished in a number of ways. There is the
/// the configuration's global default 'inUse' setting. This is the fallback selector
/// if there are no other selections. The returned tuple will contain the default toolchain
/// version and the result will be .globalDefault. This will always be the result if
/// the globalDefault parameter is true.
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
public func selectToolchain(_ ctx: SwiftlyCoreContext, config: inout Config, globalDefault: Bool = false) async throws -> (ToolchainVersion?, ToolchainSelectionResult) {
    if !globalDefault {
        var cwd = ctx.currentDirectory

        while !cwd.isEmpty && !cwd.removingRoot().isEmpty {
            guard try await fs.exists(atPath: cwd) else {
                break
            }

            let svFile = cwd / ".swift-version"

            if try await fs.exists(atPath: svFile) {
                let contents = try? String(contentsOf: svFile)

                guard let contents else {
                    return (nil, .swiftVersionFile(svFile, nil, SwiftlyError(message: "The swift version file could not be read: \(svFile)")))
                }

                guard !contents.isEmpty else {
                    return (nil, .swiftVersionFile(svFile, nil, SwiftlyError(message: "The swift version file is empty: \(svFile)")))
                }

                let selectorString = contents.replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: "\r", with: "")
                let selector: ToolchainSelector?
                do {
                    selector = try ToolchainSelector(parsing: selectorString)
                } catch {
                    return (nil, .swiftVersionFile(svFile, nil, SwiftlyError(message: "The swift version file is malformed: \(svFile) \(error)")))
                }

                guard let selector else {
                    return (nil, .swiftVersionFile(svFile, nil, SwiftlyError(message: "The swift version file is malformed: \(svFile)")))
                }

                guard let selectedToolchain = config.listInstalledToolchains(selector: selector).max() else {
                    return (nil, .swiftVersionFile(svFile, selector, SwiftlyError(message: "The swift version file `\(svFile)` uses toolchain version \(selector), but it doesn't match any of the installed toolchains. You can install the toolchain with `swiftly install`.")))
                }

                return (selectedToolchain, .swiftVersionFile(svFile, selector, nil))
            }

            cwd = cwd.removingLastComponent()
        }
    }

    // Check to ensure that the global default in use toolchain matches one of the installed toolchains, and return
    // no selected toolchain if it doesn't.
    guard let defaultInUse = config.inUse, config.listInstalledToolchains(selector: nil).contains(defaultInUse) else {
        return (nil, .globalDefault)
    }

    return (defaultInUse, .globalDefault)
}
