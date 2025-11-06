import ArgumentParser
import Foundation
import Subprocess
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
                        //  a simple init.
                        try await Init.execute(ctx, assumeYes: false, noModifyProfile: false, overwrite: false, platform: nil, verbose: false, skipInstall: false, quietShellFollowup: false)
                        return
                    } else if CommandLine.arguments.count >= 2 && ["init", "--generate-completion-script"].contains(CommandLine.arguments[1]) {
                        // Let the user run the init command or completion script generation with arguments, if any.
                        await Swiftly.main()
                        return
                    } else if CommandLine.arguments.count == 2 && ["--help", "--experimental-dump-help"].contains(CommandLine.arguments[1]) {
                        // Just print help information.
                        await Swiftly.main()
                        return
                    } else {
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

            let env = try await Swiftly.currentPlatform.proxyEnvironment(ctx, env: .inherit, toolchain: toolchain)

            let cmdConfig = Configuration(
                .name(binName),
                arguments: Arguments(Array(CommandLine.arguments[1...])),
                environment: env.updating(["SWIFTLY_PROXY_IN_PROGRESS": "1"])
            )

            let cmdResult = try await Subprocess.run(
                cmdConfig,
                input: .standardInput,
                output: .standardOutput,
                error: .standardError
            )

            if !cmdResult.terminationStatus.isSuccess {
                throw RunProgramError(terminationStatus: cmdResult.terminationStatus, config: cmdConfig)
            }
        } catch let terminated as RunProgramError {
            switch terminated.terminationStatus {
            case let .exited(code):
                exit(code)
            case .unhandledException:
                exit(1)
            }
        } catch let error as SwiftlyError {
            await ctx.message(error.message)
            exit(1)
        } catch {
            await ctx.message("\(error)")
            exit(1)
        }
    }
}
