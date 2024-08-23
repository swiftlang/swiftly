import ArgumentParser
import Foundation
#if os(Linux)
import LinuxPlatform
#elseif os(macOS)
import MacOSPlatform
#endif
import SwiftlyCore

public struct GlobalOptions: ParsableArguments {
    @Flag(name: [.customShort("y"), .long], help: "Disable confirmation prompts by assuming 'yes'")
    var assumeYes: Bool = false

    public init() {}
}

@main
public struct Swiftly: SwiftlyCommand {
    public static var configuration = CommandConfiguration(
        abstract: "A utility for installing and managing Swift toolchains.",

        version: String(describing: SwiftlyCore.version),

        subcommands: [
            Install.self,
            ListAvailable.self,
            Use.self,
            Uninstall.self,
            List.self,
            Update.self,
            Init.self,
            SelfUpdate.self,
        ]
    )

    /// The list of directories that swiftly needs to exist in order to execute.
    /// If they do not exist when a swiftly command is invoked, they will be created.
    public static var requiredDirectories: [URL] {
        [
            Swiftly.currentPlatform.swiftlyHomeDir,
            Swiftly.currentPlatform.swiftlyBinDir,
            Swiftly.currentPlatform.swiftlyToolchainsDir,
        ]
    }

    public init() {}

#if os(Linux)
    internal static let currentPlatform = Linux.currentPlatform
#elseif os(macOS)
    internal static let currentPlatform = MacOS.currentPlatform
#endif
}

public protocol SwiftlyCommand: AsyncParsableCommand {}

extension Data {
    func append(to file: URL) throws {
        if let fileHandle = FileHandle(forWritingAtPath: file.path) {
            defer {
                fileHandle.closeFile()
            }
            fileHandle.seekToEndOfFile()
            fileHandle.write(self)
        } else {
            try write(to: file, options: .atomic)
        }
    }
}

extension SwiftlyCommand {
    public mutating func validateSwiftly() throws {
        for requiredDir in Swiftly.requiredDirectories {
            guard requiredDir.fileExists() else {
                do {
                    try FileManager.default.createDirectory(at: requiredDir, withIntermediateDirectories: true)
                } catch {
                    throw Error(message: "Failed to create required directory \"\(requiredDir.path)\": \(error)")
                }
                continue
            }
        }

        // Verify that the configuration exists and can be loaded
        _ = try Config.load()
    }
}
