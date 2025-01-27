import Foundation
import SwiftlyCore

@main
public enum Proxy {
    static func main() async throws {
        do {
            let zero = CommandLine.arguments[0]
            guard let binName = zero.components(separatedBy: "/").last else {
                fatalError("Could not determine the binary name for proxying")
            }

            guard binName != "swiftly" else {
                // Treat this as a swiftly invocation, but first check that we are installed, bootstrapping
                //  the installation process if we aren't.
                let configResult = Result { try Config.load() }

                switch configResult {
                case .success:
                    await Swiftly.main()
                    return
                case let .failure(err):
                    guard CommandLine.arguments.count > 0 else { fatalError("argv is not set") }

                    if CommandLine.arguments.count == 1 {
                        // User ran swiftly with no extra arguments in an uninstalled environment, so we jump directly into
                        //  an simple init.
                        try await Init.execute(assumeYes: false, noModifyProfile: false, overwrite: false, platform: nil, verbose: false, skipInstall: false)
                        return
                    } else if CommandLine.arguments.count >= 2 && CommandLine.arguments[1] == "init" {
                        // Let the user run the init command with their arguments, if any.
                        await Swiftly.main()
                        return
                    } else if CommandLine.arguments.count == 2 && (CommandLine.arguments[1] == "--help" || CommandLine.arguments[1] == "--experimental-dump-help") {
                        // Allow the showing of help information
                        await Swiftly.main()
                        return
                    } else {
                        // We've been invoked outside the "init" subcommand and we're not yet configured.
                        // This will throw if the configuration couldn't be loaded and give the user an actionable message.
                        throw err
                    }
                }
            }

            var config = try Config.load()

            let (toolchain, result) = try await selectToolchain(config: &config)

            // Abort on any errors relating to swift version files
            if case let .swiftVersionFile(_, _, error) = result, let error = error {
                throw error
            }

            guard let toolchain = toolchain else {
                throw SwiftlyError(message: "No swift toolchain could be selected from either from a .swift-version file, or the default. You can try using `swiftly install <toolchain version>` to install one.")
            }

            try await Swiftly.currentPlatform.proxy(toolchain, binName, Array(CommandLine.arguments[1...]))
        } catch let terminated as RunProgramError {
            exit(terminated.exitCode)
        } catch let error as SwiftlyError {
            SwiftlyCore.print(error.message)
            exit(1)
        } catch {
            SwiftlyCore.print("\(error)")
            exit(1)
        }
    }
}
