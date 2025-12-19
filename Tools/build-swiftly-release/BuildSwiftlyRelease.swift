import ArgumentParser
import AsyncHTTPClient
import Foundation
import NIOFileSystem
import Subprocess
import SwiftlyCore
import SystemPackage

#if os(macOS)
import MacOSPlatform
#elseif os(Linux)
import LinuxPlatform
#endif

#if os(macOS)
let currentPlatform = MacOS()
#elseif os(Linux)
let currentPlatform = Linux()
#endif

typealias fs = SwiftlyCore.FileSystem
typealias sys = SystemCommand

extension Runnable {
    // Runs the command while echoing the full command-line to stdout for logging and reproduction
    func runEcho(environment: Environment = .inherit, quiet: Bool = false) async throws {
        let config = self.config()
        if !quiet { print("\(config.executable) \(config.arguments)") }
        try await self.run(environment: environment, quiet: quiet)
    }
}

// These functions are cloned and adapted from SwiftlyCore until we can do better bootstrapping
public struct Error: LocalizedError, CustomStringConvertible {
    public let message: String

    public init(message: String) {
        self.message = message
    }

    public var errorDescription: String { self.message }
    public var description: String { self.message }
}

@main
struct BuildSwiftlyRelease: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "build-swiftly-release",
        abstract: "Build final swiftly product for a release."
    )

    @Flag(name: .long, help: "Skip the git repo checks and proceed.")
    var skip: Bool = false

#if os(macOS)
    @Option(help: "Installation certificate to use when building the macOS package")
    var cert: String?

    @Option(help: "Package identifier of macOS package")
    var identifier: String = "org.swift.swiftly"
#elseif os(Linux)
    @Flag(name: .long, help: "Deprecated option since releases can be built on any swift supported Linux distribution.")
    var useRhelUbi9: Bool = false
#endif

    @Flag(help: "Produce a swiftly-test.tar.gz that has a standalone test suite to test the released bundle.")
    var test: Bool = false

    @Argument(help: "Version of swiftly to build the release.")
    var version: String

    func validate() throws {}

    func run() async throws {
#if os(Linux)
        try await self.buildLinuxRelease()
#elseif os(macOS)
        try await self.buildMacOSRelease(cert: self.cert, identifier: self.identifier)
#else
        #error("Unsupported OS")
#endif
    }

    func findSwiftVersion() async throws -> String? {
        var cwd = fs.cwd

        while !cwd.isEmpty && !cwd.removingRoot().isEmpty {
            guard try await fs.exists(atPath: cwd) else {
                break
            }

            let svFile = cwd / ".swift-version"

            if try await fs.exists(atPath: svFile) {
                let selector = try? String(contentsOf: svFile, encoding: .utf8)
                if let selector {
                    return selector.replacingOccurrences(of: "\n", with: "")
                }
                return selector
            }

            cwd = cwd.removingLastComponent()
        }

        return nil
    }

    func checkGitRepoStatus() async throws {
        guard !self.skip else {
            return
        }

        guard let gitTags = try await sys.git().log(.max_count("1"), .pretty("format:%d")).output(limit: 1024), gitTags.contains("tag: \(self.version)") else {
            throw Error(message: "Git repo is not yet tagged for release \(self.version). Please tag this commit with that version and push it to GitHub.")
        }

        do {
            try await sys.git().diffindex(.quiet, tree_ish: "HEAD").runEcho()
        } catch {
            throw Error(message: "Git repo has local changes. First commit these changes, tag the commit with release \(self.version) and push the tag to GitHub.")
        }
    }

    func collectLicenses(_ licenseDir: FilePath) async throws {
        try await fs.mkdir(.parents, atPath: licenseDir)

        let cwd = fs.cwd

        // Copy the swiftly license to the bundle
        try await fs.copy(atPath: cwd / "LICENSE.txt", toPath: licenseDir / "LICENSE.txt")
    }

    func buildLinuxRelease() async throws {
        try await self.checkGitRepoStatus()

        // Start with a fresh SwiftPM package
        try await sys.swift().package().reset().runEcho()

        // Build a specific version of libarchive with a check on the tarball's SHA256
        let libArchiveVersion = "3.8.1"
        let libArchiveTarSha = "bde832a5e3344dc723cfe9cc37f8e54bde04565bfe6f136bc1bd31ab352e9fab"

        let buildCheckoutsDir = fs.cwd / ".build/checkouts"
        let libArchivePath = buildCheckoutsDir / "libarchive-\(libArchiveVersion)"
        let pkgConfigPath = libArchivePath / "pkgconfig"

        try? await fs.mkdir(.parents, atPath: buildCheckoutsDir)
        try? await fs.mkdir(.parents, atPath: pkgConfigPath)

        try? await fs.remove(atPath: libArchivePath)

        // Download libarchive
        let httpExecutor = HTTPRequestExecutorImpl()
        let libarchiveRequest = HTTPClientRequest(url: "https://github.com/libarchive/libarchive/releases/download/v\(libArchiveVersion)/libarchive-\(libArchiveVersion).tar.gz")
        let libarchiveResponse = try await httpExecutor.httpClient.execute(libarchiveRequest, timeout: .seconds(60))
        guard libarchiveResponse.status == .ok else {
            throw Error(message: "Download failed with status: \(libarchiveResponse.status)")
        }

        try await NIOFileSystem.FileSystem.shared.withFileHandle(forWritingAt: buildCheckoutsDir / "libarchive-\(libArchiveVersion).tar.gz", options: .newFile(replaceExisting: true)) { fileHandle in
            var pos: Int64 = 0

            for try await buffer in libarchiveResponse.body {
                pos += try await fileHandle.write(contentsOf: buffer, toAbsoluteOffset: pos)
            }
        }

        let libArchiveTarShaActual = try await sys.sha256sum(files: buildCheckoutsDir / "libarchive-\(libArchiveVersion).tar.gz").output(limit: 1024)
        guard let libArchiveTarShaActual, libArchiveTarShaActual.starts(with: libArchiveTarSha) else {
            let shaActual = libArchiveTarShaActual ?? "none"
            throw Error(message: "The libarchive tar.gz file sha256sum is \(shaActual), but expected \(libArchiveTarSha)")
        }
        try await sys.tar(.directory(buildCheckoutsDir)).extract(.compressed, .archive(buildCheckoutsDir / "libarchive-\(libArchiveVersion).tar.gz")).runEcho()

        let cwd = fs.cwd
        FileManager.default.changeCurrentDirectoryPath(libArchivePath.string)

        let swiftVerRegex: Regex<(Substring, Substring)> = try! Regex("Swift version (\\d+\\.\\d+\\.?\\d*) ")

        let swiftVersionCmd = Configuration(
            .name("swift"),
            arguments: ["--version"]
        )
        print("\(swiftVersionCmd.executable) \(swiftVersionCmd.arguments)")

        let swiftVerOutput = (try await Subprocess.run(swiftVersionCmd, output: .string(limit: 1024))).standardOutput ?? ""
        guard let swiftVerMatch = try swiftVerRegex.firstMatch(in: swiftVerOutput) else {
            throw Error(message: "Unable to detect swift version")
        }

        let swiftVersion = swiftVerMatch.output.1
        guard let swiftRelease = (try await httpExecutor.getReleaseToolchains()).first(where: { $0.name == swiftVersion }) else {
            throw Error(message: "Unable to find swift release using swift.org API: \(swiftVersion)")
        }

        let sdkName = "swift-\(swiftVersion)-RELEASE_static-linux-0.0.1"

#if arch(arm64)
        let arch = "aarch64"
#else
        let arch = "x86_64"
#endif

        guard let sdkPlatform = swiftRelease.platforms.first(where: { $0.name == "Static SDK" }) else {
            throw Error(message: "Swift release \(swiftVersion) has no Static SDK offering")
        }

        // try await sys.swift().sdk().install(.checksum(sdkPlatform.checksum ?? "deadbeef"), bundle_path_or_url: "https://download.swift.org/swift-\(swiftVersion)-release/static-sdk/swift-\(swiftVersion)-RELEASE/swift-\(swiftVersion)-RELEASE_static-linux-0.0.1.artifactbundle.tar.gz").runEcho()

        // Download and extract SDK into the build checkouts directory
        let sdkRequest = HTTPClientRequest(url: "https://download.swift.org/swift-\(swiftVersion)-release/static-sdk/swift-\(swiftVersion)-RELEASE/swift-\(swiftVersion)-RELEASE_static-linux-0.0.1.artifactbundle.tar.gz")
        let sdkResponse = try await httpExecutor.httpClient.execute(sdkRequest, timeout: .seconds(60))
        guard sdkResponse.status == .ok else {
            throw Error(message: "Download failed with status: \(sdkResponse.status)")
        }

        try await NIOFileSystem.FileSystem.shared.withFileHandle(forWritingAt: buildCheckoutsDir / "static-linux-sdk.tar.gz", options: .newFile(replaceExisting: true)) { fileHandle in
            var pos: Int64 = 0

            for try await buffer in sdkResponse.body {
                pos += try await fileHandle.write(contentsOf: buffer, toAbsoluteOffset: pos)
            }
        }

        guard let sdkShaActual = try await sys.sha256sum(files: buildCheckoutsDir / "static-linux-sdk.tar.gz").output(limit: 1024) else { throw Error(message: "Unable to calculate sha256sum of static-linux-sdk.tar.gz") }
        guard sdkShaActual.starts(with: sdkPlatform.checksum ?? "beefdead") else {
            throw Error(message: "The static linux sdk tar.gz file sha256sum is \(sdkShaActual), but expected \(sdkPlatform.checksum)")
        }

        let sdkDir = fs.mktemp()
        try await fs.mkdir(atPath: sdkDir)

        try await sys.tar(.directory(sdkDir)).extract(.compressed, .archive(buildCheckoutsDir / "static-linux-sdk.tar.gz")).runEcho()

        var customEnv: Environment = .inherit
        customEnv = customEnv.updating([
            "CC": "\(cwd)/Tools/build-swiftly-release/musl-clang",
            "MUSL_PREFIX": "\(sdkDir / "\(sdkName).artifactbundle/\(sdkName)/swift-linux-musl/musl-1.2.5.sdk/\(arch)/usr")",
        ])

        let configCmd = Configuration(
            .path(FilePath("./configure")),
            arguments: [
                "--prefix=\(pkgConfigPath)",
                "--enable-shared=no",
                "--with-pic",
                "--without-nettle",
                "--without-openssl",
                "--without-lzo2",
                "--without-expat",
                "--without-xml2",
                "--without-bz2lib",
                "--without-libb2",
                "--without-iconv",
                "--without-zstd",
                "--without-lzma",
                "--without-lz4",
                "--disable-acl",
                "--disable-bsdtar",
                "--disable-bsdcat",
            ],
            environment: customEnv,
        )
        print("\(configCmd.executable) \(configCmd.arguments)")

        let result = try await Subprocess.run(
            configCmd,
            output: .standardOutput,
            error: .standardError,
        )

        if !result.terminationStatus.isSuccess {
            throw RunProgramError(terminationStatus: result.terminationStatus, config: configCmd)
        }

        try await sys.make().runEcho(environment: customEnv)

        try await sys.make().install().runEcho()

        FileManager.default.changeCurrentDirectoryPath(cwd.string)

        try await sys.swift().build(.swift_sdks_path(sdkDir.string), .swift_sdk("swift-\(swiftVersion)-RELEASE_static-linux-0.0.1"), .arch(arch), .product("swiftly"), .pkg_config_path(pkgConfigPath / "lib/pkgconfig"), .configuration("release")).runEcho()

        let releaseDir = cwd / ".build/release"

        // Strip the symbols from the binary to decrease its size
        try await sys.strip(name: releaseDir / "swiftly").runEcho()

        try await self.collectLicenses(releaseDir)

        let releaseArchive = releaseDir / "swiftly-\(version)-\(arch).tar.gz"

        try await sys.tar(.directory(releaseDir)).create(.compressed, .archive(releaseArchive), files: ["swiftly", "LICENSE.txt"]).runEcho()

        print(releaseArchive)

        if self.test {
            let debugDir = cwd / ".build/debug"

#if arch(arm64)
            let testArchive = debugDir / "test-swiftly-linux-aarch64.tar.gz"
#else
            let testArchive = debugDir / "test-swiftly-linux-x86_64.tar.gz"
#endif

            try await sys.swift().build(.swift_sdk("\(arch)-swift-linux-musl"), .product("test-swiftly"), .pkg_config_path(pkgConfigPath / "lib/pkgconfig"), .static_swift_stdlib, .configuration("debug")).runEcho()
            try await sys.tar(.directory(debugDir)).create(.compressed, .archive(testArchive), files: ["test-swiftly"]).runEcho()

            print(testArchive)
        }

        try await fs.remove(atPath: sdkDir)
    }

    func buildMacOSRelease(cert: String?, identifier: String) async throws {
        try await self.checkGitRepoStatus()

        try await sys.swift().package().clean().runEcho()

        for arch in ["x86_64", "arm64"] {
            try await sys.swift().build(.product("swiftly"), .configuration("release"), .arch("\(arch)")).runEcho()
            try await sys.strip(name: FilePath(".build") / "\(arch)-apple-macosx/release/swiftly").runEcho()
        }

        let swiftlyBinDir = fs.cwd / ".build/release/.swiftly/bin"
        try? await fs.mkdir(.parents, atPath: swiftlyBinDir)

        try await sys.lipo(
            input_file: ".build/x86_64-apple-macosx/release/swiftly", ".build/arm64-apple-macosx/release/swiftly"
        )
        .create(.output(swiftlyBinDir / "swiftly"))
        .runEcho()

        let swiftlyLicenseDir = fs.cwd / ".build/release/.swiftly/license"
        try? await fs.mkdir(.parents, atPath: swiftlyLicenseDir)
        try await self.collectLicenses(swiftlyLicenseDir)

        let cwd = fs.cwd

        let releaseDir = cwd / ".build/release"
        let pkgFile = releaseDir / "swiftly-\(self.version).pkg"

        if let cert {
            try await sys.pkgbuild(
                .install_location(".swiftly"),
                .version(self.version),
                .identifier(identifier),
                .sign(cert),
                .root(swiftlyBinDir.parent),
                package_output_path: releaseDir / "swiftly-\(self.version).pkg"
            ).runEcho()
        } else {
            try await sys.pkgbuild(
                .install_location(".swiftly"),
                .version(self.version),
                .identifier(identifier),
                .root(swiftlyBinDir.parent),
                package_output_path: releaseDir / "swiftly-\(self.version).pkg"
            ).runEcho()
        }

        // Re-configure the pkg to prefer installs into the current user's home directory with the help of productbuild.
        // Note that command-line installs can override this preference, but the GUI install will limit the choices.

        let pkgFileReconfigured = releaseDir / "swiftly-\(self.version)-reconfigured.pkg"
        let distFile = releaseDir / "distribution.plist"

        try await sys.productbuild(.synthesize, .pkg_path(pkgFile), output_path: distFile).runEcho()

        var distFileContents = try String(contentsOf: distFile, encoding: .utf8)
        distFileContents = distFileContents.replacingOccurrences(of: "<choices-outline>", with: "<title>swiftly</title><domains enable_anywhere=\"false\" enable_currentUserHome=\"true\" enable_localSystem=\"false\"/><choices-outline>")
        try distFileContents.write(to: distFile, atomically: true, encoding: .utf8)

        if let cert = cert {
            try await sys.productbuild(.search_path(pkgFile.parent), .cert(cert), .dist_path(distFile), output_path: pkgFileReconfigured).runEcho()
        } else {
            try await sys.productbuild(.search_path(pkgFile.parent), .dist_path(distFile), output_path: pkgFileReconfigured).runEcho()
        }
        try await fs.remove(atPath: pkgFile)
        try await fs.copy(atPath: pkgFileReconfigured, toPath: pkgFile)

        print(pkgFile)

        if self.test {
            for arch in ["x86_64", "arm64"] {
                try await sys.swift().build(.product("test-swiftly"), .configuration("debug"), .arch("\(arch)")).runEcho()
                try await sys.strip(name: ".build" / "\(arch)-apple-macosx/release/swiftly").runEcho()
            }

            let testArchive = releaseDir / "test-swiftly-macos.tar.gz"

            try await sys.lipo(
                input_file: ".build/x86_64-apple-macosx/debug/test-swiftly", ".build/arm64-apple-macosx/debug/test-swiftly"
            )
            .create(.output(swiftlyBinDir / "swiftly"))
            .runEcho()

            try await sys.tar(.directory(".build/x86_64-apple-macosx/debug")).create(.compressed, .archive(testArchive), files: ["test-swiftly"]).runEcho()

            print(testArchive)
        }
    }
}
