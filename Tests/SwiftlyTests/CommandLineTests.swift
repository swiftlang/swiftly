import Foundation
@testable import Swiftly
@testable import SwiftlyCore
import SystemPackage
import Testing

public typealias sys = SystemCommand

@Suite
public struct CommandLineTests {
    @Test func testDsclModel() {
        var config = sys.dscl(datasource: ".").read(path: .init("/Users/swiftly"), key: ["UserShell"]).config()
        #expect(config.executable == .name("dscl"))
        #expect(config.arguments.storage.map(\.description) == [".", "-read", "/Users/swiftly", "UserShell"])

        config = sys.dscl(datasource: ".").read(path: .init("/Users/swiftly"), key: ["UserShell", "Picture"]).config()
        #expect(config.executable == .name("dscl"))
        #expect(config.arguments.storage.map(\.description) == [".", "-read", "/Users/swiftly", "UserShell", "Picture"])
    }

    @Test(
        .tags(.medium),
        .enabled {
            try await sys.dsclCommand.defaultExecutable.exists()
        }
    )
    func testDscl() async throws {
        let properties = try await sys.dscl(datasource: ".").read(path: fs.home, key: ["UserShell"]).properties(Swiftly.currentPlatform)
        #expect(properties.count == 1) // Only one shell for the current user
        #expect(properties[0].key == "UserShell") // The one property key should be the one that is requested
    }

    @Test func testLipo() {
        var config = sys.lipo(input_file: "swiftly1", "swiftly2").create(.output("swiftly-universal")).config()

        #expect(config.executable == .name("lipo"))
        #expect(config.arguments.storage.map(\.description) == ["swiftly1", "swiftly2", "-create", "-output", "swiftly-universal"])

        config = sys.lipo(input_file: "swiftly").create(.output("swiftly-universal-with-one-arch")).config()
        #expect(config.executable == .name("lipo"))
        #expect(config.arguments.storage.map(\.description) == ["swiftly", "-create", "-output", "swiftly-universal-with-one-arch"])
    }

    @Test func testPkgbuild() {
        var config = sys.pkgbuild(.root("mypath"), package_output_path: "outputDir").config()
        #expect(String(describing: config) == "pkgbuild --root mypath outputDir")

        config = sys.pkgbuild(.version("1234"), .root("somepath"), package_output_path: "output").config()
        #expect(String(describing: config) == "pkgbuild --version 1234 --root somepath output")

        config = sys.pkgbuild(.install_location("/usr/local"), .version("1.0.0"), .identifier("org.foo.bar"), .sign("mycert"), .root("someroot"), package_output_path: "my.pkg").config()
        #expect(String(describing: config) == "pkgbuild --install-location /usr/local --version 1.0.0 --identifier org.foo.bar --sign mycert --root someroot my.pkg")

        config = sys.pkgbuild(.install_location("/usr/local"), .version("1.0.0"), .identifier("org.foo.bar"), .root("someroot"), package_output_path: "my.pkg").config()
        #expect(String(describing: config) == "pkgbuild --install-location /usr/local --version 1.0.0 --identifier org.foo.bar --root someroot my.pkg")
    }

    @Test func testGetent() {
        var config = sys.getent(database: "passwd", key: "swiftly").config()
        #expect(String(describing: config) == "getent passwd swiftly")

        config = sys.getent(database: "foo", key: "abc", "def").config()
        #expect(String(describing: config) == "getent foo abc def")
    }

    @Test func testGitModel() {
        var config = sys.git().log(.max_count("1"), .pretty("format:%d")).config()
        #expect(String(describing: config) == "git log --max-count 1 --pretty format:%d")

        config = sys.git().log().config()
        #expect(String(describing: config) == "git log")

        config = sys.git().log(.pretty("foo")).config()
        #expect(String(describing: config) == "git log --pretty foo")

        config = sys.git().diffindex(.quiet, tree_ish: "HEAD").config()
        #expect(String(describing: config) == "git diff-index --quiet HEAD")

        config = sys.git().diffindex(tree_ish: "main").config()
        #expect(String(describing: config) == "git diff-index main")
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
        try await sys.git(.workingDir(tmp))._init().run(Swiftly.currentPlatform)

        // AND a simple history
        try "Some text".write(to: tmp / "foo.txt", atomically: true)
        try await Swiftly.currentPlatform.runProgram("git", "-C", "\(tmp)", "add", "foo.txt")
        try await Swiftly.currentPlatform.runProgram("git", "-C", "\(tmp)", "config", "user.email", "user@example.com")
        try await sys.git(.workingDir(tmp)).commit(.message("Initial commit")).run(Swiftly.currentPlatform)
        try await sys.git(.workingDir(tmp)).diffindex(.quiet, tree_ish: "HEAD").run(Swiftly.currentPlatform)

        // WHEN inspecting the log
        let log = try await sys.git(.workingDir(tmp)).log(.max_count("1")).output(Swiftly.currentPlatform)!
        // THEN it is not empty
        #expect(log != "")

        // WHEN there is a change to the work tree
        try "Some new text".write(to: tmp / "foo.txt", atomically: true)

        // THEN diff index finds a change
        try await #expect(throws: Error.self) {
            try await sys.git(.workingDir(tmp)).diffindex(.quiet, tree_ish: "HEAD").run(Swiftly.currentPlatform)
        }
    }

    @Test func testTarModel() {
        var config = sys.tar(.directory("/some/cool/stuff")).create(.compressed, .archive("abc.tgz"), files: "a", "b").config()
        #expect(String(describing: config) == "tar -C /some/cool/stuff -c -z --file abc.tgz a b")

        config = sys.tar().create(.archive("myarchive.tar")).config()
        #expect(String(describing: config) == "tar -c --file myarchive.tar")

        config = sys.tar(.directory("/this/is/the/place")).extract(.compressed, .archive("def.tgz")).config()
        #expect(String(describing: config) == "tar -C /this/is/the/place -x -z --file def.tgz")

        config = sys.tar().extract(.archive("somearchive.tar")).config()
        #expect(String(describing: config) == "tar -x --file somearchive.tar")
    }

    @Test(
        .tags(.medium),
        .enabled {
            try await sys.TarCommand.defaultExecutable.exists()
        }
    )
    func testTar() async throws {
        let tmp = fs.mktemp()
        try await fs.mkdir(atPath: tmp)
        let readme = "README.md"
        try await "README".write(to: tmp / readme, atomically: true)

        let arch = fs.mktemp(ext: "tar")
        let archCompressed = fs.mktemp(ext: "tgz")

        try await sys.tar(.directory(tmp)).create(.verbose, .archive(arch), files: FilePath(readme)).run(Swiftly.currentPlatform)
        try await sys.tar(.directory(tmp)).create(.verbose, .compressed, .archive(archCompressed), files: FilePath(readme)).run(Swiftly.currentPlatform)

        let tmp2 = fs.mktemp()
        try await fs.mkdir(atPath: tmp2)

        try await sys.tar(.directory(tmp2)).extract(.verbose, .archive(arch)).run(Swiftly.currentPlatform)

        let contents = try await String(contentsOf: tmp2 / readme, encoding: .utf8)
        #expect(contents == "README")

        let tmp3 = fs.mktemp()
        try await fs.mkdir(atPath: tmp3)

        try await sys.tar(.directory(tmp3)).extract(.verbose, .compressed, .archive(archCompressed)).run(Swiftly.currentPlatform)

        let contents2 = try await String(contentsOf: tmp3 / readme, encoding: .utf8)
        #expect(contents2 == "README")
    }

    @Test func testSwiftModel() async throws {
        var config = sys.swift().package().reset().config()
        #expect(String(describing: config) == "swift package reset")

        config = sys.swift().package().clean().config()
        #expect(String(describing: config) == "swift package clean")

        config = sys.swift().sdk().install("path/to/bundle", checksum: "deadbeef").config()
        #expect(String(describing: config) == "swift sdk install path/to/bundle --checksum=deadbeef")

        config = sys.swift().sdk().remove("some.bundle").config()
        #expect(String(describing: config) == "swift sdk remove some.bundle")

        config = sys.swift().build(.arch("x86_64"), .configuration("release"), .pkgConfigPath("path/to/pc"), .swiftSdk("sdk.id"), .staticSwiftStdlib, .product("product1")).config()
        #expect(String(describing: config) == "swift build --arch=x86_64 --configuration=release --pkg-config-path=path/to/pc --swift-sdk=sdk.id --static-swift-stdlib --product=product1")

        config = sys.swift().build().config()
        #expect(String(describing: config) == "swift build")
    }

    @Test(
        .tags(.medium),
        .enabled {
            try await sys.SwiftCommand.defaultExecutable.exists()
        }
    )
    func testSwift() async throws {
        let tmp = fs.mktemp()
        try await fs.mkdir(atPath: tmp)
        try await sys.swift().package()._init(.packagePath(tmp), .type("executable")).run(Swiftly.currentPlatform)
        try await sys.swift().build(.packagePath(tmp), .configuration("release"))
    }

    @Test func testMake() async throws {
        var config = sys.make().install().config()
        #expect(String(describing: config) == "make install")
    }

    @Test func testStrip() async throws {
        var config = sys.strip(names: FilePath("foo")).config()
        #expect(String(describing: config) == "strip foo")
    }

    @Test func testSha256Sum() async throws {
        var config = sys.sha256sum(files: FilePath("abcde")).config()
        #expect(String(describing: config) == "sha256sum abcde")
    }

    @Test func testProductBuild() async throws {
        var config = sys.productbuild().synthesize(package: FilePath("mypkg"), distributionOutputPath: FilePath("distribution")).config()
        #expect(String(describing: config) == "productbuild --synthesize --package mypkg distribution")

        config = sys.productbuild().distribution(distPath: FilePath("mydist"), productOutputPath: FilePath("product")).config()
        #expect(String(describing: config) == "productbuild --distribution mydist product")

        config = sys.productbuild().distribution(.packagePath(FilePath("pkgpath")), .sign("mycert"), distPath: FilePath("mydist"), productOutputPath: FilePath("myproduct")).config()
        #expect(String(describing: config) == "productbuild --distribution mydist --package-path pkgpath --sign mycert myproduct")
    }

    @Test func testGpg() async throws {
        var config = sys.gpg()._import(keys: FilePath("somekeys.asc")).config()
        #expect(String(describing: config) == "gpg --import somekeys.asc")

        config = sys.gpg().verify(detachedSignature: FilePath("file.sig"), signedData: FilePath("file")).config()
        #expect(String(describing: config) == "gpg --verify file.sig file")
    }

    @Test func testPkgutil() async throws {
        var config = sys.pkgutil(.verbose).checkSignature(pkgPath: FilePath("path/to/my.pkg")).config()
        #expect(String(describing: config) == "pkgutil --verbose --check-signature path/to/my.pkg")

        config = sys.pkgutil(.verbose).expand(pkgPath: FilePath("path/to/my.pkg"), dirPath: FilePath("expand/to/here")).config()
        #expect(String(describing: config) == "pkgutil --verbose --expand path/to/my.pkg expand/to/here")

        config = sys.pkgutil(.volume("/Users/foo")).forget(packageId: "com.example.pkg").config()
        #expect(String(describing: config) == "pkgutil --volume /Users/foo --forget com.example.pkg")
    }

    @Test func testInstaller() async throws {
        var config = sys.installer(.verbose, pkg: FilePath("path/to/my.pkg"), target: "CurrentUserHomeDirectory").config()
        #expect(String(describing: config) == "installer -verbose -pkg path/to/my.pkg -target CurrentUserHomeDirectory")
    }
}
