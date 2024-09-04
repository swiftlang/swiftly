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
                await Swiftly.main()
                return
            }

            let config = try Config.load()
            let toolchain: ToolchainVersion

            if let (selectedToolchain, versionFile, selector) = try swiftToolchainSelection(config: config) {
                guard let selectedToolchain = selectedToolchain else {
                    if let versionFile = versionFile {
                        throw if let selector = selector {
                            Error(message: "No installed swift toolchain matches the version \(selector) from \(versionFile). You can try installing one with `swiftly install \(selector)`.")
                        } else {
                            Error(message: "Swift version file is malformed and cannot be used to select a swift toolchain: \(versionFile)")
                        }
                    }
                    fatalError("error in toolchain selection logic")
                }

                toolchain = selectedToolchain
            } else {
                throw Error(message: "No swift toolchain could be determined either from a .swift-version file, or the default. You can try using `swiftly use <toolchain version>` to set it.")
            }

            try await Swiftly.currentPlatform.proxy(toolchain, binName, Array(CommandLine.arguments[1...]))
        } catch {
            SwiftlyCore.print("\(error)")
            exit(1)
        }
    }
}
