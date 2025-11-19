import Foundation
import Subprocess
@testable import Swiftly
@testable import SwiftlyCore
import SystemPackage
import Testing

public typealias sys = SystemCommand

@Suite
public struct CommandLineTests {
    @Test func testDsclModel() {
        var cmd = sys.dscl(datasource: ".").read(path: .init("/Users/swiftly"), key: ["UserShell"])
        var config = cmd.config()
        var args = cmd.commandArgs()
        #expect(config.executable == .name("dscl"))
        #expect(args == [".", "-read", "/Users/swiftly", "UserShell"])

        cmd = sys.dscl(datasource: ".").read(path: .init("/Users/swiftly"), key: ["UserShell", "Picture"])
        config = cmd.config()
        args = cmd.commandArgs()
        #expect(config.executable == .name("dscl"))
        #expect(args == [".", "-read", "/Users/swiftly", "UserShell", "Picture"])
    }

    @Test(
        .tags(.medium),
        .enabled {
            try await sys.dsclCommand.defaultExecutable.exists()
        }
    )
    func testDscl() async throws {
        let properties = try await sys.dscl(datasource: ".").read(path: fs.home, key: ["UserShell"]).properties(Swiftly.currentPlatform)

        guard properties.count == 1 else {
            Issue.record("Unexpected number of properties. There is only one shell for the current user.")
            return
        }

        #expect(properties[0].key == "UserShell") // The one property key should be the one that is requested
    }

    @Test func testLipo() {
        var cmd = sys.lipo(input_file: "swiftly1", "swiftly2").create(.output("swiftly-universal"))
        var config = cmd.config()
        var args = cmd.commandArgs()

        #expect(config.executable == .name("lipo"))
        #expect(args == ["swiftly1", "swiftly2", "-create", "-output", "swiftly-universal"])

        cmd = sys.lipo(input_file: "swiftly").create(.output("swiftly-universal-with-one-arch"))
        config = cmd.config()
        args = cmd.commandArgs()

        #expect(config.executable == .name("lipo"))
        #expect(args == ["swiftly", "-create", "-output", "swiftly-universal-with-one-arch"])
    }

    @Test func testPkgbuild() {
        var cmd = sys.pkgbuild(.root("mypath"), package_output_path: "outputDir")
        var config = cmd.config()
        var args = cmd.commandArgs()
        #expect(config.executable == .name("pkgbuild"))
        #expect(args == ["--root", "mypath", "outputDir"])

        cmd = sys.pkgbuild(.version("1234"), .root("somepath"), package_output_path: "output")
        config = cmd.config()
        args = cmd.commandArgs()
        #expect(config.executable == .name("pkgbuild"))
        #expect(args == ["--version", "1234", "--root", "somepath", "output"])

        cmd = sys.pkgbuild(.install_location("/usr/local"), .version("1.0.0"), .identifier("org.foo.bar"), .sign("mycert"), .root("someroot"), package_output_path: "my.pkg")
        config = cmd.config()
        args = cmd.commandArgs()
        #expect(config.executable == .name("pkgbuild"))
        #expect(args == ["--install-location", "/usr/local", "--version", "1.0.0", "--identifier", "org.foo.bar", "--sign", "mycert", "--root", "someroot", "my.pkg"])

        cmd = sys.pkgbuild(.install_location("/usr/local"), .version("1.0.0"), .identifier("org.foo.bar"), .root("someroot"), package_output_path: "my.pkg")
        config = cmd.config()
        args = cmd.commandArgs()
        #expect(config.executable == .name("pkgbuild"))
        #expect(args == ["--install-location", "/usr/local", "--version", "1.0.0", "--identifier", "org.foo.bar", "--root", "someroot", "my.pkg"])
    }

    @Test func testGetent() {
        var cmd = sys.getent(database: "passwd", key: "swiftly")
        var config = cmd.config()
        var args = cmd.commandArgs()
        #expect(config.executable == .name("getent"))
        #expect(args == ["passwd", "swiftly"])

        cmd = sys.getent(database: "foo", key: "abc", "def")
        config = cmd.config()
        args = cmd.commandArgs()
        #expect(config.executable == .name("getent"))
        #expect(args == ["foo", "abc", "def"])
    }

    @Test func testGitModel() {
        var cmd = sys.git().log(.max_count("1"), .pretty("format:%d"))
        var config = cmd.config()
        var args = cmd.commandArgs()
        #expect(config.executable == .name("git"))
        #expect(args == ["log", "--max-count", "1", "--pretty", "format:%d"])

        cmd = sys.git().log()
        config = cmd.config()
        args = cmd.commandArgs()
        #expect(config.executable == .name("git"))
        #expect(args == ["log"])

        cmd = sys.git().log(.pretty("foo"))
        config = cmd.config()
        args = cmd.commandArgs()
        #expect(config.executable == .name("git"))
        #expect(args == ["log", "--pretty", "foo"])

        var indexCmd = sys.git().diffindex(.quiet, tree_ish: "HEAD")
        config = indexCmd.config()
        args = indexCmd.commandArgs()
        #expect(config.executable == .name("git"))
        #expect(args == ["diff-index", "--quiet", "HEAD"])

        indexCmd = sys.git().diffindex(tree_ish: "main")
        config = indexCmd.config()
        args = indexCmd.commandArgs()
        #expect(config.executable == .name("git"))
        #expect(args == ["diff-index", "main"])
    }

    @Test(
        .tags(.medium),
        .enabled {
            try await sys.gitCommand.defaultExecutable.exists()
        }
    )
    func testGit() async throws {
        // GIVEN a simple git repository
        let tmp = fs.mktemp()
        try await fs.mkdir(atPath: tmp)
        try await sys.git(.workingDir(tmp))._init().run()

        // AND a simple history
        try "Some text".write(to: tmp / "foo.txt", atomically: true)
        try #require(try await run(.name("git"), arguments: ["-C", "\(tmp)", "add", "foo.txt"], output: .standardOutput).terminationStatus.isSuccess)
        try #require(try await run(.name("git"), arguments: ["-C", "\(tmp)", "config", "--local", "user.email", "user@example.com"], output: .standardOutput).terminationStatus.isSuccess)
        try #require(try await run(.name("git"), arguments: ["-C", "\(tmp)", "config", "--local", "commit.gpgsign", "false"], output: .standardOutput).terminationStatus.isSuccess)
        try await sys.git(.workingDir(tmp)).commit(.message("Initial commit")).run()
        try await sys.git(.workingDir(tmp)).diffindex(.quiet, tree_ish: "HEAD").run()

        // WHEN inspecting the log
        let log = try await sys.git(.workingDir(tmp)).log(.max_count("1")).output(limit: 1024 * 10)!
        // THEN it is not empty
        #expect(log != "")

        // WHEN there is a change to the work tree
        try "Some new text".write(to: tmp / "foo.txt", atomically: true)

        // THEN diff index finds a change
        await #expect(throws: Error.self) {
            try await sys.git(.workingDir(tmp)).diffindex(.quiet, tree_ish: "HEAD").run()
        }
    }

    @Test func testTarModel() {
        var cmd = sys.tar(.directory("/some/cool/stuff")).create(.compressed, .archive("abc.tgz"), files: ["a", "b"])
        var config = cmd.config()
        var args = cmd.commandArgs()
        #expect(config.executable == .name("tar"))
        #expect(args == ["-C", "/some/cool/stuff", "--create", "-z", "--file", "abc.tgz", "a", "b"])

        cmd = sys.tar().create(.archive("myarchive.tar"), files: nil)
        config = cmd.config()
        args = cmd.commandArgs()
        #expect(config.executable == .name("tar"))
        #expect(args == ["--create", "--file", "myarchive.tar"])

        var extractCmd = sys.tar(.directory("/this/is/the/place")).extract(.compressed, .archive("def.tgz"))
        config = extractCmd.config()
        args = extractCmd.commandArgs()
        #expect(config.executable == .name("tar"))
        #expect(args == ["-C", "/this/is/the/place", "--extract", "-z", "--file", "def.tgz"])

        extractCmd = sys.tar().extract(.archive("somearchive.tar"))
        config = extractCmd.config()
        args = extractCmd.commandArgs()
        #expect(config.executable == .name("tar"))
        #expect(args == ["--extract", "--file", "somearchive.tar"])
    }

    @Test(
        .tags(.medium),
        .enabled {
            try await sys.tarCommand.defaultExecutable.exists()
        }
    )
    func testTar() async throws {
        let tmp = fs.mktemp()
        try await fs.mkdir(atPath: tmp)
        let readme = "README.md"
        try "README".write(to: tmp / readme, atomically: true)

        let arch = fs.mktemp(ext: "tar")
        let archCompressed = fs.mktemp(ext: "tgz")

        try await sys.tar(.directory(tmp)).create(.verbose, .archive(arch), files: [FilePath(readme)]).run()
        try await sys.tar(.directory(tmp)).create(.verbose, .compressed, .archive(archCompressed), files: [FilePath(readme)]).run()

        let tmp2 = fs.mktemp()
        try await fs.mkdir(atPath: tmp2)

        try await sys.tar(.directory(tmp2)).extract(.verbose, .archive(arch)).run()

        let contents = try String(contentsOf: tmp2 / readme, encoding: .utf8)
        #expect(contents == "README")

        let tmp3 = fs.mktemp()
        try await fs.mkdir(atPath: tmp3)

        try await sys.tar(.directory(tmp3)).extract(.verbose, .compressed, .archive(archCompressed)).run()

        let contents2 = try String(contentsOf: tmp3 / readme, encoding: .utf8)
        #expect(contents2 == "README")
    }

    @Test func testSwiftModel() async throws {
        let cmd = sys.swift().package().reset()
        var config = cmd.config()
        var args = cmd.commandArgs()
        #expect(config.executable == .name("swift"))
        #expect(args == ["package", "reset"])

        let cleanCmd = sys.swift().package().clean()
        config = cleanCmd.config()
        args = cleanCmd.commandArgs()
        #expect(config.executable == .name("swift"))
        #expect(args == ["package", "clean"])

        let installCmd = sys.swift().sdk().install(.checksum("deadbeef"), bundle_path_or_url: "path/to/bundle")
        config = installCmd.config()
        args = installCmd.commandArgs()
        #expect(config.executable == .name("swift"))
        #expect(args == ["sdk", "install", "--checksum", "deadbeef", "path/to/bundle"])

        let removeCmd = sys.swift().sdk().remove([], sdk_id_or_bundle_name: "some.bundle")
        config = removeCmd.config()
        args = removeCmd.commandArgs()
        #expect(config.executable == .name("swift"))
        #expect(args == ["sdk", "remove", "some.bundle"])

        var buildCmd = sys.swift().build(.arch("x86_64"), .configuration("release"), .pkg_config_path("path/to/pc"), .swift_sdk("sdk.id"), .static_swift_stdlib, .product("product1"))
        config = buildCmd.config()
        args = buildCmd.commandArgs()
        #expect(config.executable == .name("swift"))
        #expect(args == ["build", "--arch", "x86_64", "--configuration", "release", "--pkg-config-path", "path/to/pc", "--swift-sdk", "sdk.id", "--static-swift-stdlib", "--product", "product1"])

        buildCmd = sys.swift().build()
        config = buildCmd.config()
        args = buildCmd.commandArgs()
        #expect(config.executable == .name("swift"))
        #expect(args == ["build"])
    }

    @Test(
        .tags(.medium),
        .enabled {
            try await sys.swiftCommand.defaultExecutable.exists()
        }
    )
    func testSwift() async throws {
        let tmp = fs.mktemp()
        try await fs.mkdir(atPath: tmp)
        let swiftExec: Executable = .path(try Executable.name("swift").resolveExecutablePath(in: .inherit))
        try await sys.swift(executable: swiftExec).package()._init(.package_path(tmp), .type("executable")).run()
        try await sys.swift(executable: swiftExec).build(.package_path(tmp), .configuration("release")).run()
    }

    @Test func testMake() async throws {
        let cmd = sys.make().install()
        let config = cmd.config()
        let args = cmd.commandArgs()
        #expect(config.executable == .name("make"))
        #expect(args == ["install"])
    }

    @Test func testStrip() async throws {
        let cmd = sys.strip(name: FilePath("foo"))
        let config = cmd.config()
        let args = cmd.commandArgs()
        #expect(config.executable == .name("strip"))
        #expect(args == ["foo"])
    }

    @Test func testSha256Sum() async throws {
        let cmd = sys.sha256sum(files: FilePath("abcde"))
        let config = cmd.config()
        let args = cmd.commandArgs()
        #expect(config.executable == .name("sha256sum"))
        #expect(args == ["abcde"])
    }

    @Test func testProductBuild() async throws {
        var cmd = sys.productbuild(.synthesize, .pkg_path(FilePath("mypkg")), output_path: FilePath("distribution"))
        var config = cmd.config()
        var args = cmd.commandArgs()
        #expect(config.executable == .name("productbuild"))
        #expect(args == ["--synthesize", "--package", "mypkg", "distribution"])

        cmd = sys.productbuild(.dist_path(FilePath("mydist")), output_path: FilePath("product"))
        config = cmd.config()
        args = cmd.commandArgs()
        #expect(config.executable == .name("productbuild"))
        #expect(args == ["--distribution", "mydist", "product"])

        cmd = sys.productbuild(.dist_path(FilePath("mydist")), .search_path(FilePath("pkgpath")), .cert("mycert"), output_path: FilePath("myproduct"))
        config = cmd.config()
        args = cmd.commandArgs()
        #expect(config.executable == .name("productbuild"))
        #expect(args == ["--distribution", "mydist", "--package-path", "pkgpath", "--sign", "mycert", "myproduct"])
    }

    @Test func testGpg() async throws {
        let cmd = sys.gpg()._import(key: FilePath("somekeys.asc"))
        var config = cmd.config()
        var args = cmd.commandArgs()
        #expect(config.executable == .name("gpg"))
        #expect(args == ["--import", "somekeys.asc"])

        let verifyCmd = sys.gpg().verify(detached_signature: FilePath("file.sig"), signed_data: FilePath("file"))
        config = verifyCmd.config()
        args = verifyCmd.commandArgs()
        #expect(config.executable == .name("gpg"))
        #expect(args == ["--verify", "file.sig", "file"])
    }

    @Test func testPkgutil() async throws {
        let checkSigCmd = sys.pkgutil(.verbose).checksignature(pkg_path: FilePath("path/to/my.pkg"))
        var config = checkSigCmd.config()
        var args = checkSigCmd.commandArgs()
        #expect(config.executable == .name("pkgutil"))
        #expect(args == ["--verbose", "--check-signature", "path/to/my.pkg"])

        let expandCmd = sys.pkgutil(.verbose).expand(pkg_path: FilePath("path/to/my.pkg"), dir_path: FilePath("expand/to/here"))
        config = expandCmd.config()
        args = expandCmd.commandArgs()
        #expect(config.executable == .name("pkgutil"))
        #expect(args == ["--verbose", "--expand", "path/to/my.pkg", "expand/to/here"])

        let forgetCmd = sys.pkgutil(.volume("/Users/foo")).forget(pkg_id: "com.example.pkg")
        config = forgetCmd.config()
        args = forgetCmd.commandArgs()
        #expect(config.executable == .name("pkgutil"))
        #expect(args == ["--volume", "/Users/foo", "--forget", "com.example.pkg"])
    }

    @Test func testInstaller() async throws {
        let cmd = sys.installer(.verbose, .pkg(FilePath("path/to/my.pkg")), .target("CurrentUserHomeDirectory"))
        let config = cmd.config()
        let args = cmd.commandArgs()
        #expect(config.executable == .name("installer"))
        #expect(args == ["-verbose", "-pkg", "path/to/my.pkg", "-target", "CurrentUserHomeDirectory"])
    }
}
