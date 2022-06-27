import ArgumentParser

internal struct SelfUpdate: AsyncParsableCommand {
    public static var configuration = CommandConfiguration(
        abstract: "Update the version of swiftly itself."
    )

    internal mutating func run() async throws {
        print("updating swiftly")
        try await currentPlatform.selfUpdate()
    }
}
