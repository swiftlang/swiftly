@testable import Swiftly
@testable import SwiftlyCore
import SystemPackage
import Testing

public typealias sys = SystemCommand

@Suite
public struct CommandLineTests {
    @Test func testDsclModel() {
        var config = sys.dscl(datasource: ".").read(path: .init("/Users/swiftly"), keys: "UserShell").config()
        #expect(config.executable == .name("dscl"))
        #expect(config.arguments.storage.map(\.description) == [".", "-read", "/Users/swiftly", "UserShell"])

        config = sys.dscl(datasource: ".").read(path: .init("/Users/swiftly"), keys: "UserShell", "Picture").config()
        #expect(config.executable == .name("dscl"))
        #expect(config.arguments.storage.map(\.description) == [".", "-read", "/Users/swiftly", "UserShell", "Picture"])
    }

    @Test(
        .tags(.medium),
        .enabled {
            try await sys.DsclCommand.defaultExecutable.exists()
        }
    )
    func testDscl() async throws {
        let properties = try await sys.dscl(datasource: ".").read(path: fs.home, keys: "UserShell").properties(Swiftly.currentPlatform)
        #expect(properties.count == 1) // Only one shell for the current user
        #expect(properties[0].key == "UserShell") // The one property key should be the one that is requested
    }

    @Test func testLipo() {
        var config = sys.lipo(inputFiles: "swiftly1", "swiftly2").create(output: "swiftly-universal").config()

        #expect(config.executable == .name("lipo"))
        #expect(config.arguments.storage.map(\.description) == ["swiftly1", "swiftly2", "-create", "-output", "swiftly-universal"])

        config = sys.lipo(inputFiles: "swiftly").create(output: "swiftly-universal-with-one-arch").config()
        #expect(config.executable == .name("lipo"))
        #expect(config.arguments.storage.map(\.description) == ["swiftly", "-create", "-output", "swiftly-universal-with-one-arch"])
    }

    @Test func testPkgbuild() {
        var config = sys.pkgbuild(root: "mypath", packageOutputPath: "outputDir").config()
        #expect(String(describing: config) == "pkgbuild --root mypath outputDir")

        config = sys.pkgbuild(.version("1234"), root: "somepath", packageOutputPath: "output").config()
        #expect(String(describing: config) == "pkgbuild --version 1234 --root somepath output")
    }
}
