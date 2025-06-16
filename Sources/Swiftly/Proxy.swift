import ArgumentParser
import Foundation
import SwiftlyCore

@main
public enum Proxy {
    static func main() async throws {
        let ctx = SwiftlyCoreContext()

        do {
            let zero = CommandLine.arguments[0]
            guard let binName = zero.components(separatedBy: "/").last else {
                fatalError("Could not determine the binary name for proxying")
            }

            guard binName != "swiftly" else {
                if CommandLine.arguments.count > 1, CommandLine.arguments[1] == "--generate-completion-script" {
                    // If the first argument is for completion script generation, we let swiftly handle it and finish.
                    return await Swiftly.main()
                }
                // Treat this as a swiftly invocation, but first check that we are installed, bootstrapping
                //  the installation process if we aren't.
                let configResult: Result<Config, any Error>
                do {
                    configResult = Result<Config, any Error>.success(try await Config.load(ctx))
                } catch {
                    configResult = Result<Config, any Error>.failure(error)
                }

                switch configResult {
                case .success:
                    await Swiftly.main()
                    return
                case let .failure(err):
                    guard CommandLine.arguments.count > 0 else { fatalError("argv is not set") }

                    if CommandLine.arguments.count == 1 {
                        // User ran swiftly with no extra arguments in an uninstalled environment, so we jump directly into
                        //  an simple init.
                        try await Init.execute(ctx, assumeYes: false, noModifyProfile: false, overwrite: false, platform: nil, verbose: false, skipInstall: false, quietShellFollowup: false)
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

            var config = try await Config.load(ctx)

            let (toolchain, result) = try await selectToolchain(ctx, config: &config)

            // Abort on any errors relating to swift version files
            if case let .swiftVersionFile(_, _, error) = result, let error = error {
                throw error
            }

            guard let toolchain = toolchain else {
                throw SwiftlyError(message: "No installed swift toolchain is selected from either from a .swift-version file, or the default. You can try using one that's already installed with `swiftly use <toolchain version>` or install a new toolchain to use with `swiftly install --use <toolchain version>`.")
            }

            // Prevent circularities with a memento environment variable
            guard ProcessInfo.processInfo.environment["SWIFTLY_PROXY_IN_PROGRESS"] == nil else {
                throw SwiftlyError(message: "Circular swiftly proxy invocation")
            }
            let env = ["SWIFTLY_PROXY_IN_PROGRESS": "1"]

            try await Swiftly.currentPlatform.proxy(ctx, toolchain, binName, Array(CommandLine.arguments[1...]), env)
        } catch let terminated as RunProgramError {
            exit(terminated.exitCode)
        } catch let error as SwiftlyError {
            await ctx.message(error.message)
            exit(1)
        } catch {
            await ctx.message("\(error)")
            exit(1)
        }
    }
}
