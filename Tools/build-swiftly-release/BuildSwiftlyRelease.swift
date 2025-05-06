import ArgumentParser
import AsyncHTTPClient
import Foundation
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

typealias fs = FileSystem
typealias sys = SystemCommand

extension Runnable {
    // Runs the command while echoing the full command-line to stdout for logging and reproduction
    func runEcho(_ platform: Platform, quiet: Bool = false) async throws {
        let config = self.config()
        // if !quiet { print("\(args.joined(separator: " "))") }
        if !quiet { print("\(config)") }

        try await self.run(platform)
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

        guard let gitTags = try await sys.git().log(.max_count("1"), .pretty("format:%d")).output(currentPlatform), gitTags.contains("tag: \(self.version)") else {
            throw Error(message: "Git repo is not yet tagged for release \(self.version). Please tag this commit with that version and push it to GitHub.")
        }

        do {
            try await sys.git().diffindex(.quiet, tree_ish: "HEAD").run(currentPlatform)
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
        try await sys.swift().package().reset().run(currentPlatform)

        // Build a specific version of libarchive with a check on the tarball's SHA256
        let libArchiveVersion = "3.7.9"
        let libArchiveTarSha = "aa90732c5a6bdda52fda2ad468ac98d75be981c15dde263d7b5cf6af66fd009f"

        let buildCheckoutsDir = fs.cwd / ".build/checkouts"
        let libArchivePath = buildCheckoutsDir / "libarchive-\(libArchiveVersion)"
        let pkgConfigPath = libArchivePath / "pkgconfig"

        try? await fs.mkdir(.parents, atPath: buildCheckoutsDir)
        try? await fs.mkdir(.parents, atPath: pkgConfigPath)

        try? await fs.remove(atPath: libArchivePath)

        // Download libarchive
        let libarchiveRequest = HTTPClientRequest(url: "https://github.com/libarchive/libarchive/releases/download/v\(libArchiveVersion)/libarchive-\(libArchiveVersion).tar.gz")
        let libarchiveResponse = try await HTTPClient.shared.execute(libarchiveRequest, timeout: .seconds(60))
        guard libarchiveResponse.status == .ok else {
            throw Error(message: "Download failed with status: \(libarchiveResponse.status)")
        }
        let buf = try await libarchiveResponse.body.collect(upTo: 20 * 1024 * 1024)
        guard let contents = buf.getBytes(at: 0, length: buf.readableBytes) else {
            throw Error(message: "Unable to read all of the bytes")
        }
        let data = Data(contents)
        try data.write(to: buildCheckoutsDir / "libarchive-\(libArchiveVersion).tar.gz")

        let libArchiveTarShaActual = try await sys.sha256sum(files: buildCheckoutsDir / "libarchive-\(libArchiveVersion).tar.gz").output(currentPlatform)
        guard let libArchiveTarShaActual, libArchiveTarShaActual.starts(with: libArchiveTarSha) else {
            let shaActual = libArchiveTarShaActual ?? "none"
            throw Error(message: "The libarchive tar.gz file sha256sum is \(shaActual), but expected \(libArchiveTarSha)")
        }
        try await sys.tar(.directory(buildCheckoutsDir)).extract(.compressed, .archive(buildCheckoutsDir / "libarchive-\(libArchiveVersion).tar.gz")).run(currentPlatform)

        let cwd = fs.cwd
        FileManager.default.changeCurrentDirectoryPath(libArchivePath.string)

        let swiftVerRegex: Regex<(Substring, Substring)> = try! Regex("Swift version (\\d+\\.\\d+\\.?\\d*) ")

        let swiftVerOutput = (try await currentPlatform.runProgramOutput("swift", "--version")) ?? ""
        guard let swiftVerMatch = try swiftVerRegex.firstMatch(in: swiftVerOutput) else {
            throw Error(message: "Unable to detect swift version")
        }

        let swiftVersion = swiftVerMatch.output.1

        let httpExecutor = HTTPRequestExecutorImpl()
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

        try await sys.swift().sdk().install(.checksum(sdkPlatform.checksum ?? "deadbeef"), bundle_path_or_url: "https://download.swift.org/swift-\(swiftVersion)-release/static-sdk/swift-\(swiftVersion)-RELEASE/swift-\(swiftVersion)-RELEASE_static-linux-0.0.1.artifactbundle.tar.gz").run(currentPlatform)

        var customEnv = ProcessInfo.processInfo.environment
        customEnv["CC"] = "\(cwd)/Tools/build-swiftly-release/musl-clang"
        customEnv["MUSL_PREFIX"] = "\(fs.home / ".swiftpm/swift-sdks/\(sdkName).artifactbundle/\(sdkName)/swift-linux-musl/musl-1.2.5.sdk/\(arch)/usr")"

        try currentPlatform.runProgram(
            "./configure",
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
            env: customEnv
        )

        try await sys.make().run(currentPlatform, env: customEnv)

        try await sys.make().install().run(currentPlatform)

        FileManager.default.changeCurrentDirectoryPath(cwd.string)

        try await sys.swift().build(.swift_sdk("\(arch)-swift-linux-musl"), .product("swiftly"), .pkg_config_path(pkgConfigPath / "lib/pkgconfig"), .static_swift_stdlib, .configuration("release")).run(currentPlatform)

        let releaseDir = cwd / ".build/release"

        // Strip the symbols from the binary to decrease its size
        try await sys.strip(names: releaseDir / "swiftly").run(currentPlatform)

        try await self.collectLicenses(releaseDir)

#if arch(arm64)
        let releaseArchive = releaseDir / "swiftly-\(version)-aarch64.tar.gz"
#else
        let releaseArchive = releaseDir / "swiftly-\(version)-x86_64.tar.gz"
#endif

        try await sys.tar(.directory(releaseDir)).create(.compressed, .archive(releaseArchive), files: ["swiftly", "LICENSE.txt"]).run(currentPlatform)

        print(releaseArchive)

        if self.test {
            let debugDir = cwd / ".build/debug"

#if arch(arm64)
            let testArchive = debugDir / "test-swiftly-linux-aarch64.tar.gz"
#else
            let testArchive = debugDir / "test-swiftly-linux-x86_64.tar.gz"
#endif

            try await sys.swift().build(.swift_sdk("\(arch)-swift-linux-musl"), .product("test-swiftly"), .pkg_config_path(pkgConfigPath / "lib/pkgconfig"), .static_swift_stdlib, .configuration("debug")).run(currentPlatform)
            try await sys.tar(.directory(debugDir)).create(.compressed, .archive(testArchive), files: ["test-swiftly"]).run(currentPlatform)

            print(testArchive)
        }

        try await sys.swift().sdk().remove(sdk_id_or_bundle_name: sdkName).runEcho(currentPlatform)
    }

    func buildMacOSRelease(cert: String?, identifier: String) async throws {
        try await self.checkGitRepoStatus()

        try await sys.swift().package().clean().run(currentPlatform)

        for arch in ["x86_64", "arm64"] {
            try await sys.swift().build(.product("swiftly"), .configuration("release"), .arch("\(arch)")).run(currentPlatform)
            try await sys.strip(names: FilePath(".build") / "\(arch)-apple-macosx/release/swiftly").run(currentPlatform)
        }

        let swiftlyBinDir = fs.cwd / ".build/release/.swiftly/bin"
        try? await fs.mkdir(.parents, atPath: swiftlyBinDir)

        try await sys.lipo(
            input_file: ".build/x86_64-apple-macosx/release/swiftly", ".build/arm64-apple-macosx/release/swiftly"
        )
        .create(.output(swiftlyBinDir / "swiftly"))
        .runEcho(currentPlatform)

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
            ).runEcho(currentPlatform)
        } else {
            try await sys.pkgbuild(
                .install_location(".swiftly"),
                .version(self.version),
                .identifier(identifier),
                .root(swiftlyBinDir.parent),
                package_output_path: releaseDir / "swiftly-\(self.version).pkg"
            ).runEcho(currentPlatform)
        }

        // Re-configure the pkg to prefer installs into the current user's home directory with the help of productbuild.
        // Note that command-line installs can override this preference, but the GUI install will limit the choices.

        let pkgFileReconfigured = releaseDir / "swiftly-\(self.version)-reconfigured.pkg"
        let distFile = releaseDir / "distribution.plist"

        try await sys.productbuild().synthesize(package: pkgFile, distributionOutputPath: distFile).runEcho(currentPlatform)

        var distFileContents = try String(contentsOf: distFile, encoding: .utf8)
        distFileContents = distFileContents.replacingOccurrences(of: "<choices-outline>", with: "<title>swiftly</title><domains enable_anywhere=\"false\" enable_currentUserHome=\"true\" enable_localSystem=\"false\"/><choices-outline>")
        try distFileContents.write(to: distFile, atomically: true, encoding: .utf8)

        if let cert = cert {
            try await sys.productbuild().distribution(.packagePath(pkgFile.parent), .sign(cert), distPath: distFile, productOutputPath: pkgFileReconfigured).runEcho(currentPlatform)
        } else {
            try await sys.productbuild().distribution(.packagePath(pkgFile.parent), distPath: distFile, productOutputPath: pkgFileReconfigured).runEcho(currentPlatform)
        }
        try await fs.remove(atPath: pkgFile)
        try await fs.copy(atPath: pkgFileReconfigured, toPath: pkgFile)

        print(pkgFile)

        if self.test {
            for arch in ["x86_64", "arm64"] {
                try await sys.swift().build(.product("test-swiftly"), .configuration("debug"), .arch("\(arch)")).runEcho(currentPlatform)
                try await sys.strip(names: ".build" / "\(arch)-apple-macosx/release/swiftly").runEcho(currentPlatform)
            }

            let testArchive = releaseDir / "test-swiftly-macos.tar.gz"

            try await sys.lipo(
                input_file: ".build/x86_64-apple-macosx/debug/test-swiftly", ".build/arm64-apple-macosx/debug/test-swiftly"
            )
            .create(.output(swiftlyBinDir / "swiftly"))
            .runEcho(currentPlatform)

            try await sys.tar(.directory(".build/x86_64-apple-macosx/debug")).create(.compressed, .archive(testArchive), files: ["test-swiftly"]).run(currentPlatform)

            print(testArchive)
        }
    }
}
