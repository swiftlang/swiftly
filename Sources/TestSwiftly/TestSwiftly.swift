import ArgumentParser
import Foundation
import SwiftlyCore

#if os(Linux)
import LinuxPlatform
#elseif os(macOS)
import MacOSPlatform
#endif

#if os(Linux)
let currentPlatform: Platform = Linux.currentPlatform
#elseif os(macOS)
let currentPlatform: Platform = MacOS.currentPlatform
#else
#error("Unsupported platform")
#endif

@main
struct TestSwiftly: AsyncParsableCommand {
    @Flag(name: [.customShort("y"), .long], help: "Disable confirmation prompts by assuming 'yes'")
    var assumeYes: Bool = false

    @Flag(help: "Install swiftly to a custom location, not added to the user profile.")
    var customLocation: Bool = false

    @Argument var swiftlyArchive: String? = nil

    mutating func run() async throws {
        if !self.assumeYes {
            print("WARNING: This test will mutate your system to test the swiftly installation end-to-end. Please run this on a fresh system and try again with '--assume-yes'.")
            Foundation.exit(2)
        }

        guard let swiftlyArchive = self.swiftlyArchive else {
            print("ERROR: You must provide a swiftly archive path for the test.")
            Foundation.exit(2)
        }

        print("Extracting swiftly release")
#if os(Linux)
        try currentPlatform.runProgram("tar", "-zxvf", swiftlyArchive, quiet: false)
#elseif os(macOS)
        try currentPlatform.runProgram("installer", "-pkg", swiftlyArchive, "-target", "CurrentUserHomeDirectory", quiet: false)
#endif

#if os(Linux)
        let extractedSwiftly = "./swiftly"
#elseif os(macOS)
        let extractedSwiftly = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".swiftly/bin/swiftly").path
#endif

        var env = ProcessInfo.processInfo.environment
        let shell = try await currentPlatform.getShell()
        var customLoc: URL?

        if self.customLocation {
            customLoc = currentPlatform.getTempFilePath()

            print("Installing swiftly to custom location \(customLoc!.path)")
            env["SWIFTLY_HOME_DIR"] = customLoc!.path
            env["SWIFTLY_BIN_DIR"] = customLoc!.appendingPathComponent("bin").path
            env["SWIFTLY_TOOLCHAIN_DIR"] = customLoc!.appendingPathComponent("toolchains").path

            try currentPlatform.runProgram(extractedSwiftly, "init", "--assume-yes", "--no-modify-profile", "--skip-install", quiet: false, env: env)
            try currentPlatform.runProgram(shell, "-l", "-c", ". \"\(customLoc!.path)/env.sh\" && swiftly install --assume-yes latest --post-install-file=./post-install.sh", quiet: false, env: env)
        } else {
            print("Installing swiftly to the default location.")
            // Setting this environment helps to ensure that the profile gets sourced with bash, even if it is not in an interactive shell
            if shell.hasSuffix("bash") {
                env["BASH_ENV"] = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".profile").path
            } else if shell.hasSuffix("zsh") {
                env["ZDOTDIR"] = FileManager.default.homeDirectoryForCurrentUser.path
            } else if shell.hasSuffix("fish") {
                env["XDG_CONFIG_HOME"] = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config").path
            }

            try currentPlatform.runProgram(extractedSwiftly, "init", "--assume-yes", "--skip-install", quiet: false, env: env)
            try currentPlatform.runProgram(shell, "-l", "-c", "swiftly install --assume-yes latest --post-install-file=./post-install.sh", quiet: false, env: env)
        }

        var swiftReady = false

        if NSUserName() == "root" && FileManager.default.fileExists(atPath: "./post-install.sh") {
            try currentPlatform.runProgram(shell, "./post-install.sh", quiet: false)
            swiftReady = true
        } else if FileManager.default.fileExists(atPath: "./post-install.sh") {
            print("WARNING: not running as root, so skipping the post installation steps and final swift verification.")
        } else {
            swiftReady = true
        }

        if let customLoc = customLoc, swiftReady {
            try currentPlatform.runProgram(shell, "-l", "-c", ". \"\(customLoc.path)/env.sh\" && swift --version", quiet: false, env: env)
        } else if swiftReady {
            try currentPlatform.runProgram(shell, "-l", "-c", "swift --version", quiet: false, env: env)
        }
    }
}
