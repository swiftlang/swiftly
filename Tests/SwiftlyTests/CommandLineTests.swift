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
        var config = sys.lipo(inputFiles: FilePath("swiftly1"), FilePath("swiftly2")).create(.output(FilePath("swiftly-universal"))).config()

        #expect(config.executable == .name("lipo"))
        #expect(config.arguments.storage.map(\.description) == ["swiftly1", "swiftly2", "-create", "-output", "swiftly-universal"])
    }
}
