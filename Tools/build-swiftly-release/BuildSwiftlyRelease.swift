import ArgumentParser
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

public struct SwiftPlatform: Codable {
    public var name: String?
    public var checksum: String?
}

public struct SwiftRelease: Codable {
    public var name: String?
    public var platforms: [SwiftPlatform]?
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

public func runProgramEnv(_ args: String..., quiet: Bool = false, env: [String: String]?) throws {
    if !quiet { print("\(args.joined(separator: " "))") }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = args

    if let env = env {
        process.environment = env
    }

    if quiet {
        process.standardOutput = nil
        process.standardError = nil
    }

    try process.run()
    // Attach this process to our process group so that Ctrl-C and other signals work
    let pgid = tcgetpgrp(STDOUT_FILENO)
    if pgid != -1 {
        tcsetpgrp(STDOUT_FILENO, process.processIdentifier)
    }
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
        throw Error(message: "\(args.first!) exited with non-zero status: \(process.terminationStatus)")
    }
}

public func runProgram(_ args: String..., quiet: Bool = false) throws {
    if !quiet { print("\(args.joined(separator: " "))") }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = args

    if quiet {
        process.standardOutput = nil
        process.standardError = nil
    }

    try process.run()
    // Attach this process to our process group so that Ctrl-C and other signals work
    let pgid = tcgetpgrp(STDOUT_FILENO)
    if pgid != -1 {
        tcsetpgrp(STDOUT_FILENO, process.processIdentifier)
    }
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
        throw Error(message: "\(args.first!) exited with non-zero status: \(process.terminationStatus)")
    }
}

public func runProgramOutput(_ program: String, _ args: String...) async throws -> String? {
    print("\(program) \(args.joined(separator: " "))")

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = [program] + args

    let outPipe = Pipe()
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = outPipe

    try process.run()
    // Attach this process to our process group so that Ctrl-C and other signals work
    let pgid = tcgetpgrp(STDOUT_FILENO)
    if pgid != -1 {
        tcsetpgrp(STDOUT_FILENO, process.processIdentifier)
    }
    let outData = try outPipe.fileHandleForReading.readToEnd()

    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
        print("\(args.first!) exited with non-zero status: \(process.terminationStatus)")
        throw Error(message: "\(args.first!) exited with non-zero status: \(process.terminationStatus)")
    }

    if let outData {
        return String(data: outData, encoding: .utf8)
    } else {
        return nil
    }
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

    func assertTool(_ name: String, message: String) async throws -> String {
        guard let _ = try? await runProgramOutput(currentPlatform.getShell(), "-c", "which which") else {
            throw Error(message: "The which command could not be found. Please install it with your package manager.")
        }

        guard let location = try? await runProgramOutput(currentPlatform.getShell(), "-c", "which \(name)") else {
            throw Error(message: message)
        }

        return location.replacingOccurrences(of: "\n", with: "")
    }

    func findSwiftVersion() throws -> String? {
        var cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

        while cwd.path != "" && cwd.path != "/" {
            guard FileManager.default.fileExists(atPath: cwd.path) else {
                break
            }

            let svFile = cwd.appendingPathComponent(".swift-version")

            if FileManager.default.fileExists(atPath: svFile.path) {
                let selector = try? String(contentsOf: svFile, encoding: .utf8)
                if let selector {
                    return selector.replacingOccurrences(of: "\n", with: "")
                }
                return selector
            }

            cwd = cwd.deletingLastPathComponent()
        }

        return nil
    }

    func checkGitRepoStatus() async throws {
        guard !self.skip else {
            return
        }

        guard let gitTags = try await sys.git().log(.maxCount(1), .pretty("format:%d")).output(currentPlatform), gitTags.contains("tag: \(self.version)") else {
            throw Error(message: "Git repo is not yet tagged for release \(self.version). Please tag this commit with that version and push it to GitHub.")
        }

        do {
            try await sys.git().diffIndex(.quiet, treeIsh: "HEAD").run(currentPlatform)
        } catch {
            throw Error(message: "Git repo has local changes. First commit these changes, tag the commit with release \(self.version) and push the tag to GitHub.")
        }
    }

    func collectLicenses(_ licenseDir: String) async throws {
        try FileManager.default.createDirectory(atPath: licenseDir, withIntermediateDirectories: true)

        let cwd = FileManager.default.currentDirectoryPath

        // Copy the swiftly license to the bundle
        try FileManager.default.copyItem(atPath: cwd + "/LICENSE.txt", toPath: licenseDir + "/LICENSE.txt")
    }

    func buildLinuxRelease() async throws {
        // TODO: turn these into checks that the system meets the criteria for being capable of using the toolchain + checking for packages, not tools
        let curl = try await self.assertTool("curl", message: "Please install curl with `yum install curl`")

        try await self.checkGitRepoStatus()

        // Start with a fresh SwiftPM package
        try await sys.swift().package().reset().run(currentPlatform)

        // Build a specific version of libarchive with a check on the tarball's SHA256
        let libArchiveVersion = "3.7.9"
        let libArchiveTarSha = "aa90732c5a6bdda52fda2ad468ac98d75be981c15dde263d7b5cf6af66fd009f"

        let buildCheckoutsDir = FileManager.default.currentDirectoryPath + "/.build/checkouts"
        let libArchivePath = buildCheckoutsDir + "/libarchive-\(libArchiveVersion)"
        let pkgConfigPath = libArchivePath + "/pkgconfig"

        try? FileManager.default.createDirectory(atPath: buildCheckoutsDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(atPath: pkgConfigPath, withIntermediateDirectories: true)

        try? FileManager.default.removeItem(atPath: libArchivePath)
        try runProgram(curl, "-L", "-o", "\(buildCheckoutsDir + "/libarchive-\(libArchiveVersion).tar.gz")", "--remote-name", "--location", "https://github.com/libarchive/libarchive/releases/download/v\(libArchiveVersion)/libarchive-\(libArchiveVersion).tar.gz")
        let libArchiveTarShaActual = try await sys.sha256sum(files: FilePath("\(buildCheckoutsDir)/libarchive-\(libArchiveVersion).tar.gz")).output(currentPlatform)
        guard let libArchiveTarShaActual, libArchiveTarShaActual.starts(with: libArchiveTarSha) else {
            let shaActual = libArchiveTarShaActual ?? "none"
            throw Error(message: "The libarchive tar.gz file sha256sum is \(shaActual), but expected \(libArchiveTarSha)")
        }
        try await sys.tar(.directory(FilePath(buildCheckoutsDir))).extract(.compressed, .archive(FilePath("\(buildCheckoutsDir)/libarchive-\(libArchiveVersion).tar.gz"))).run(currentPlatform)

        let cwd = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(libArchivePath)

        let swiftVerRegex: Regex<(Substring, Substring)> = try! Regex("Swift version (\\d+\\.\\d+\\.?\\d*) ")

        let swiftVerOutput = (try await runProgramOutput("swift", "--version")) ?? ""
        guard let swiftVerMatch = try swiftVerRegex.firstMatch(in: swiftVerOutput) else {
            throw Error(message: "Unable to detect swift version")
        }

        let swiftVersion = swiftVerMatch.output.1

        let sdkName = "swift-\(swiftVersion)-RELEASE_static-linux-0.0.1"

#if arch(arm64)
        let arch = "aarch64"
#else
        let arch = "x86_64"
#endif

        let swiftReleasesJson = (try await runProgramOutput(curl, "https://www.swift.org/api/v1/install/releases.json")) ?? "[]"
        let swiftReleases = try JSONDecoder().decode([SwiftRelease].self, from: swiftReleasesJson.data(using: .utf8)!)

        guard let swiftRelease = swiftReleases.first(where: { ($0.name ?? "") == swiftVersion }) else {
            throw Error(message: "Unable to find swift release using swift.org API: \(swiftVersion)")
        }

        guard let sdkPlatform = (swiftRelease.platforms ?? [SwiftPlatform]()).first(where: { ($0.name ?? "") == "Static SDK" }) else {
            throw Error(message: "Swift release \(swiftVersion) has no Static SDK offering")
        }

        try await sys.swift().sdk().install("https://download.swift.org/swift-\(swiftVersion)-release/static-sdk/swift-\(swiftVersion)-RELEASE/swift-\(swiftVersion)-RELEASE_static-linux-0.0.1.artifactbundle.tar.gz", checksum: sdkPlatform.checksum ?? "deadbeef").run(currentPlatform)

        var customEnv = ProcessInfo.processInfo.environment
        customEnv["CC"] = "\(cwd)/Tools/build-swiftly-release/musl-clang"
        customEnv["MUSL_PREFIX"] = "\(FileManager.default.homeDirectoryForCurrentUser.path)/.swiftpm/swift-sdks/\(sdkName).artifactbundle/\(sdkName)/swift-linux-musl/musl-1.2.5.sdk/\(arch)/usr"

        try runProgramEnv(
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

        FileManager.default.changeCurrentDirectoryPath(cwd)

        try await sys.swift().build(.swiftSdk("\(arch)-swift-linux-musl"), .product("swiftly"), .pkgConfigPath("\(pkgConfigPath)/lib/pkgconfig"), .staticSwiftStdlib, .configuration("release")).run(currentPlatform)

        let releaseDir = cwd + "/.build/release"

        // Strip the symbols from the binary to decrease its size
        try await sys.strip(names: FilePath(releaseDir) / "swiftly").run(currentPlatform)

        try await self.collectLicenses(releaseDir)

#if arch(arm64)
        let releaseArchive = "\(releaseDir)/swiftly-\(version)-aarch64.tar.gz"
#else
        let releaseArchive = "\(releaseDir)/swiftly-\(version)-x86_64.tar.gz"
#endif

        try await sys.tar(.directory(FilePath(releaseDir))).create(.compressed, .archive(FilePath(releaseArchive)), files: "swiftly", "LICENSE.txt").run(currentPlatform)

        print(releaseArchive)

        if self.test {
            let debugDir = cwd + "/.build/debug"

#if arch(arm64)
            let testArchive = "\(debugDir)/test-swiftly-linux-aarch64.tar.gz"
#else
            let testArchive = "\(debugDir)/test-swiftly-linux-x86_64.tar.gz"
#endif

            try await sys.swift().build(.swiftSdk("\(arch)-swift-linux-musl"), .product("test-swiftly"), .pkgConfigPath("\(pkgConfigPath)/lib/pkgconfig"), .staticSwiftStdlib, .configuration("debug")).run(currentPlatform)
            try await sys.tar(.directory(FilePath(debugDir))).create(.compressed, .archive(FilePath(testArchive)), files: "test-swiftly").run(currentPlatform)

            print(testArchive)
        }

        try await sys.swift().sdk().remove(sdkName)
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
            inputFiles: ".build/x86_64-apple-macosx/release/swiftly", ".build/arm64-apple-macosx/release/swiftly"
        )
        .create(output: swiftlyBinDir / "swiftly")
        .runEcho(currentPlatform)

        let swiftlyLicenseDir = FileManager.default.currentDirectoryPath + "/.build/release/.swiftly/license"
        try? FileManager.default.createDirectory(atPath: swiftlyLicenseDir, withIntermediateDirectories: true)
        try await self.collectLicenses(swiftlyLicenseDir)

        let cwd = FileManager.default.currentDirectoryPath

        let releaseDir = URL(fileURLWithPath: cwd + "/.build/release")
        let pkgFile = releaseDir.appendingPathComponent("/swiftly-\(self.version).pkg")

        if let cert {
            try await sys.pkgbuild(
                .installLocation(".swiftly"),
                .version(self.version),
                .identifier(identifier),
                .sign(cert),
                root: swiftlyBinDir.parent,
                packageOutputPath: FilePath(".build/release/swiftly-\(self.version).pkg")
            ).runEcho(currentPlatform)
        } else {
            try await sys.pkgbuild(
                .installLocation(".swiftly"),
                .version(self.version),
                .identifier(identifier),
                root: swiftlyBinDir.parent,
                packageOutputPath: FilePath(".build/release/swiftly-\(self.version).pkg")
            ).runEcho(currentPlatform)
        }

        // Re-configure the pkg to prefer installs into the current user's home directory with the help of productbuild.
        // Note that command-line installs can override this preference, but the GUI install will limit the choices.

        let pkgFileReconfigured = releaseDir.appendingPathComponent("swiftly-\(self.version)-reconfigured.pkg")
        let distFile = releaseDir.appendingPathComponent("distribution.plist")

        try await sys.productbuild().synthesize(package: FilePath(pkgFile.path), distributionOutputPath: FilePath(distFile.path))

        var distFileContents = try String(contentsOf: distFile, encoding: .utf8)
        distFileContents = distFileContents.replacingOccurrences(of: "<choices-outline>", with: "<title>swiftly</title><domains enable_anywhere=\"false\" enable_currentUserHome=\"true\" enable_localSystem=\"false\"/><choices-outline>")
        try distFileContents.write(to: distFile, atomically: true, encoding: .utf8)

        if let cert = cert {
            try await sys.productbuild().distribution(.packagePath(FilePath(pkgFile.deletingLastPathComponent().path)), .sign(cert), distPath: FilePath(distFile.path), productOutputPath: FilePath(pkgFileReconfigured.path))
        } else {
            try await sys.productbuild().distribution(.packagePath(FilePath(pkgFile.deletingLastPathComponent().path)), distPath: FilePath(distFile.path), productOutputPath: FilePath(pkgFileReconfigured.path))
        }
        try FileManager.default.removeItem(at: pkgFile)
        try FileManager.default.copyItem(atPath: pkgFileReconfigured.path, toPath: pkgFile.path)

        print(pkgFile.path)

        if self.test {
            for arch in ["x86_64", "arm64"] {
                try await sys.swift().build(.product("test-swiftly"), .configuration("debug"), .arch("\(arch)")).run(currentPlatform)
                try await sys.strip(names: FilePath(".build") / "\(arch)-apple-macosx/release/swiftly").run(currentPlatform)
            }

            let testArchive = releaseDir.appendingPathComponent("test-swiftly-macos.tar.gz")

            try await sys.lipo(
                inputFiles: ".build/x86_64-apple-macosx/debug/test-swiftly", ".build/arm64-apple-macosx/debug/test-swiftly"
            )
            .create(output: swiftlyBinDir / "swiftly")
            .runEcho(currentPlatform)

            try await sys.tar(.directory(FilePath(".build/x86_64-apple-macosx/debug"))).create(.compressed, .archive(FilePath(testArchive.path)), files: "test-swiftly").run(currentPlatform)

            print(testArchive.path)
        }
    }
}
