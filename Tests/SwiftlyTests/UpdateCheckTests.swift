import ArgumentParser
import Foundation
import Testing

@testable import Swiftly
@testable import SwiftlyCore

@Suite struct UpdateCheckTests {
    private static var newMajorVersion: SwiftlyVersion {
        SwiftlyVersion(major: SwiftlyCore.version.major + 1, minor: 0, patch: 0)
    }

    private static var newMinorVersion: SwiftlyVersion {
        SwiftlyVersion(major: SwiftlyCore.version.major, minor: SwiftlyCore.version.minor + 1, patch: 0)
    }

    private static let now = Date(timeIntervalSince1970: 1_800_000_000)
    private static let interval = Config.updateCheckInterval

    struct CheckState: Equatable {
        var lastCheck: Date?
        var latestVersion: SwiftlyVersion?
    }

    /// Seed the config with a previous check, run `command`, and report the resulting config state.
    ///
    /// The mocked server always reports `serverVersion`, so a changed config indicates that the server was queried.
    func runCheck(
        serverVersion: SwiftlyVersion,
        now: Date = UpdateCheckTests.now,
        lastCheck: Date?,
        cachedVersion: SwiftlyVersion?,
        command: (SwiftlyCoreContext) async throws -> Void
    ) async throws -> CheckState {
        var result = CheckState()
        try await SwiftlyTests.withTestHome {
            try await SwiftlyTests.withMockedSwiftlyVersion(latestSwiftlyVersion: serverVersion) {
                var ctx = SwiftlyTests.ctx
                ctx.now = { now }
                try await Config.update(ctx) {
                    $0.lastSwiftlyVersionCheck = lastCheck
                    $0.latestSwiftlyVersion = cachedVersion
                }
                try await command(ctx)
                let config = try await Config.load(ctx)
                result = CheckState(lastCheck: config.lastSwiftlyVersionCheck, latestVersion: config.latestSwiftlyVersion)
            }
        }
        return result
    }

    /// Run the check that every regular command performs on startup.
    func runValidate(lastCheck: Date?, cachedVersion: SwiftlyVersion? = SwiftlyCore.version) async throws -> CheckState {
        try await self.runCheck(
            serverVersion: Self.newMinorVersion,
            lastCheck: lastCheck,
            cachedVersion: cachedVersion
        ) { ctx in
            var command = try List.parse([])
            try await command.validateSwiftly(ctx)
        }
    }

    /// The state expected when the server was queried.
    private static var fetched: CheckState {
        CheckState(lastCheck: Self.now, latestVersion: Self.newMinorVersion)
    }

    @Test func firstCheckQueriesServer() async throws {
        let state = try await self.runValidate(lastCheck: nil, cachedVersion: nil)
        #expect(state == Self.fetched)
    }

    @Test func checkWithinIntervalIsSkipped() async throws {
        let lastCheck = Self.now.addingTimeInterval(-(Self.interval - 1))
        let state = try await self.runValidate(lastCheck: lastCheck)
        #expect(state == CheckState(lastCheck: lastCheck, latestVersion: SwiftlyCore.version))
    }

    @Test func checkImmediatelyAfterPreviousCheckIsSkipped() async throws {
        let state = try await self.runValidate(lastCheck: Self.now)
        #expect(state == CheckState(lastCheck: Self.now, latestVersion: SwiftlyCore.version))
    }

    @Test func checkExactlyAtIntervalQueriesServer() async throws {
        let state = try await self.runValidate(lastCheck: Self.now.addingTimeInterval(-Self.interval))
        #expect(state == Self.fetched)
    }

    @Test func checkAfterIntervalQueriesServer() async throws {
        let state = try await self.runValidate(lastCheck: Self.now.addingTimeInterval(-(Self.interval + 1)))
        #expect(state == Self.fetched)
    }

    @Test func checkLongAfterIntervalQueriesServer() async throws {
        let state = try await self.runValidate(lastCheck: Self.now.addingTimeInterval(-30 * Self.interval))
        #expect(state == Self.fetched)
    }

    /// A previous check in the future (e.g. the clock was changed) doesn't trigger a check until the clock catches up.
    @Test func checkRecordedInTheFutureIsSkipped() async throws {
        let lastCheck = Self.now.addingTimeInterval(3600)
        let state = try await self.runValidate(lastCheck: lastCheck)
        #expect(state == CheckState(lastCheck: lastCheck, latestVersion: SwiftlyCore.version))
    }

    /// Successive commands only query the server once per interval.
    @Test func checkIsOnlyDueAgainAfterInterval() async throws {
        try await SwiftlyTests.withTestHome {
            try await SwiftlyTests.withMockedSwiftlyVersion(latestSwiftlyVersion: Self.newMinorVersion) {
                var ctx = SwiftlyTests.ctx

                func validate(at time: Date) async throws -> CheckState {
                    ctx.now = { time }
                    var command = try List.parse([])
                    try await command.validateSwiftly(ctx)
                    let config = try await Config.load(ctx)
                    return CheckState(lastCheck: config.lastSwiftlyVersionCheck, latestVersion: config.latestSwiftlyVersion)
                }

                // The first command checks
                let first = try await validate(at: Self.now)
                #expect(first == Self.fetched)

                // A later command, within the interval, doesn't query the server so the record keeps its timestamp.
                let early = Self.now.addingTimeInterval(Self.interval - 1)
                let second = try await validate(at: early)
                #expect(second == Self.fetched)

                // Once the interval has passed, the check is recorded again.
                let due = Self.now.addingTimeInterval(Self.interval)
                let third = try await validate(at: due)
                #expect(third == CheckState(lastCheck: due, latestVersion: Self.newMinorVersion))
            }
        }
    }

    @Test func updateCheckDueCalculation() {
        let config = Config(
            inUse: nil,
            installedToolchains: [],
            platform: PlatformDefinition(name: "test", nameFull: "test", namePretty: "Test"),
            version: SwiftlyCore.version
        )
        #expect(config.isUpdateCheckDue(now: Self.now))

        var checked = config
        checked.lastSwiftlyVersionCheck = Self.now
        #expect(!checked.isUpdateCheckDue(now: Self.now))
        #expect(!checked.isUpdateCheckDue(now: Self.now.addingTimeInterval(Self.interval - 1)))
        #expect(checked.isUpdateCheckDue(now: Self.now.addingTimeInterval(Self.interval)))
    }

    /// Self-update always queries the server, regardless of when the last check was.
    @Test func selfUpdateIgnoresInterval() async throws {
        let state = try await self.runCheck(
            serverVersion: Self.newMinorVersion,
            lastCheck: Self.now.addingTimeInterval(-1),
            cachedVersion: SwiftlyCore.version
        ) { ctx in
            _ = try await SelfUpdate.execute(ctx, verbose: true, version: nil)
        }
        #expect(state == Self.fetched)
    }

    @Test func selfUpdateRecordsCheckWithNoPriorCheck() async throws {
        let state = try await self.runCheck(
            serverVersion: Self.newMajorVersion,
            lastCheck: nil,
            cachedVersion: nil
        ) { ctx in
            _ = try await SelfUpdate.execute(ctx, verbose: true, version: nil)
        }
        #expect(state == CheckState(lastCheck: Self.now, latestVersion: Self.newMajorVersion))
    }

    /// The check is recorded even when there is nothing to update to.
    @Test func selfUpdateRecordsCheckWhenAlreadyUpToDate() async throws {
        let state = try await self.runCheck(
            serverVersion: SwiftlyCore.version,
            lastCheck: Self.now.addingTimeInterval(-(Self.interval + 1)),
            cachedVersion: nil
        ) { ctx in
            _ = try await SelfUpdate.execute(ctx, verbose: true, version: nil)
        }
        #expect(state == CheckState(lastCheck: Self.now, latestVersion: SwiftlyCore.version))
    }
}
