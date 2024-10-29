import Foundation
import SwiftlyCore

// This is the allowed list of executables that we will proxy
let proxyList = [
    "clang",
    "lldb",
    "lldb-dap",
    "lldb-server",
    "clang++",
    "sourcekit-lsp",
    "clangd",
    "swift",
    "docc",
    "swiftc",
    "lld",
    "llvm-ar",
    "plutil",
    "repl_swift",
    "wasm-ld",
]

@main
public enum Proxy {
    static func main() async throws {
        do {
            let zero = CommandLine.arguments[0]
            guard let binName = zero.components(separatedBy: "/").last else {
                fatalError("Could not determine the binary name for proxying")
            }

            guard proxyList.contains(binName) else {
                // Treat this as a swiftly invocation

                let config = try? Config.load()

                if config == nil && CommandLine.arguments.count == 1 {
                    // User ran swiftly with no extra arguments in an uninstalled environment, so we skip directly into
                    //  an init.
                    try await Init.execute(assumeYes: false, noModifyProfile: false, overwrite: false, platform: nil, verbose: false, skipInstall: false)
                    return
                } else if CommandLine.arguments[1] != "init" {
                    // Check if we've been invoked outside the "init" subcommand and we're not yet configured.
                    // This will throw if the configuration couldn't be loaded and give the user an actionable message.
                    _ = try Config.load()
                }

                await Swiftly.main()
                return
            }

            var config = try Config.load()

            let (toolchain, result) = try await selectToolchain(config: &config)

            // Abort on any errors relating to swift version files
            if case let .swiftVersionFile(_, _, error) = result, let error = error {
                throw error
            }

            guard let toolchain = toolchain else {
                throw Error(message: "No swift toolchain could be selected from either from a .swift-version file, or the default. You can try using `swiftly install <toolchain version>` to install one.")
            }

            try await Swiftly.currentPlatform.proxy(toolchain, binName, Array(CommandLine.arguments[1...]))
        } catch let terminated as RunProgramError {
            exit(terminated.exitCode)
        } catch let error as Error {
            SwiftlyCore.print(error.message)
            exit(1)
        } catch {
            SwiftlyCore.print("\(error)")
            exit(1)
        }
    }
}
