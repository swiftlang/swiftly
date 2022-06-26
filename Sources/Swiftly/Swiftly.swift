import ArgumentParser

@main
@available(macOS 10.15, *)
public struct Swiftly: AsyncParsableCommand {
    public static var configuration = CommandConfiguration(
        abstract: "A utility for insalling and managing Swift toolchains.",

        version: "0.1.0",

        subcommands: [
            Install.self,
            Use.self,
            Uninstall.self,
            Update.self,
        ]
    )

    public init() {}

    public mutating func run() async throws {
        print("hello")
    }
}