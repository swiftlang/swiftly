import ArgumentParser
import Foundation
#if os(Linux)
import LinuxPlatform
#endif
import SwiftlyCore

@main
@available(macOS 10.15, *)
public struct Swiftly: SwiftlyCommand {
    public static var configuration = CommandConfiguration(
        abstract: "A utility for insalling and managing Swift toolchains.",

        version: "0.1.0",

        subcommands: [
            Install.self,
            Use.self,
            Uninstall.self,
            Update.self,
            List.self,
            ListAvailable.self,
            SelfUpdate.self,
        ]
    )

    public init() {}

    public mutating func run() async throws {}

#if os(Linux)
    internal static let currentPlatform = Linux.currentPlatform
#endif
}

public protocol SwiftlyCommand: AsyncParsableCommand {}

extension SwiftlyCommand {
    public mutating func validate() throws {
        for requiredDir in SwiftlyCore.requiredDirectories {
            guard requiredDir.fileExists() else {
                try FileManager.default.createDirectory(at: requiredDir, withIntermediateDirectories: true)
                continue
            }
        }

        // Verify that the configuration exists and can be loaded
        _ = try Config.load()
    }
}
