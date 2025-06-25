import Foundation
import SystemPackage
import Testing

@testable import SwiftlyCore

@Suite struct FileLockTests {
    @Test("FileLock creation writes process ID to lock file")
    func testFileLockCreation() async throws {
        try await SwiftlyTests.withTestHome {
            let lockPath = SwiftlyTests.ctx.mockedHomeDir! / "test.lock"

            let lock = try FileLock(at: lockPath)

            // Verify lock file exists
            #expect(try await fs.exists(atPath: lockPath))

            // Verify lock file contains process ID
            let lockData = try Data(contentsOf: URL(fileURLWithPath: lockPath.string))
            let lockContent = String(data: lockData, encoding: .utf8)
            let expectedPID = Foundation.ProcessInfo.processInfo.processIdentifier.description
            #expect(lockContent == expectedPID)

            try await lock.unlock()
        }
    }

    @Test("FileLock fails when lock file already exists")
    func testFileLockConflict() async throws {
        try await SwiftlyTests.withTestHome {
            let lockPath = SwiftlyTests.ctx.mockedHomeDir! / "conflict.lock"

            // Create first lock
            let firstLock = try FileLock(at: lockPath)

            // Attempt to create second lock should fail
            do {
                _ = try FileLock(at: lockPath)
                #expect(Bool(false), "Expected FileLockError.lockedByPID to be thrown")
            } catch let error as FileLockError {
                if case .lockedByPID = error {
                } else {
                    #expect(Bool(false), "Expected FileLockError.lockedByPID but got \(error)")
                }
            }

            try await firstLock.unlock()
        }
    }

    @Test("FileLock unlock removes lock file")
    func testFileLockUnlock() async throws {
        try await SwiftlyTests.withTestHome {
            let lockPath = SwiftlyTests.ctx.mockedHomeDir! / "unlock.lock"

            let lock = try FileLock(at: lockPath)
            #expect(try await fs.exists(atPath: lockPath))

            try await lock.unlock()
            #expect(!(try await fs.exists(atPath: lockPath)))
        }
    }

    @Test("FileLock can be reacquired after unlock")
    func testFileLockReacquisition() async throws {
        try await SwiftlyTests.withTestHome {
            let lockPath = SwiftlyTests.ctx.mockedHomeDir! / "reacquire.lock"

            // First acquisition
            let firstLock = try FileLock(at: lockPath)
            try await firstLock.unlock()

            // Second acquisition should succeed
            let secondLock = try FileLock(at: lockPath)
            try await secondLock.unlock()
        }
    }

    @Test("waitForLock succeeds immediately when no lock exists")
    func testWaitForLockImmediate() async throws {
        try await SwiftlyTests.withTestHome {
            let lockPath = SwiftlyTests.ctx.mockedHomeDir! / "immediate.lock"
            let time = Date()
            let lock = try await FileLock.waitForLock(lockPath, timeout: 1.0, pollingInterval: 0.1)
            let duration = Date().timeIntervalSince(time)
            #expect(duration < 1.0)
            #expect(try await fs.exists(atPath: lockPath))
            try await lock.unlock()
        }
    }

    @Test("waitForLock times out when lock cannot be acquired")
    func testWaitForLockTimeout() async throws {
        try await SwiftlyTests.withTestHome {
            let lockPath = SwiftlyTests.ctx.mockedHomeDir! / "timeout.lock"

            // Create existing lock
            let existingLock = try FileLock(at: lockPath)

            // Attempt to wait for lock should timeout
            do {
                _ = try await FileLock.waitForLock(lockPath, timeout: 0.5, pollingInterval: 0.1)
                #expect(Bool(false), "Expected FileLockError.lockedByPID to be thrown")
            } catch let error as FileLockError {
                if case .lockedByPID = error {
                    // Expected error
                } else {
                    #expect(Bool(false), "Expected FileLockError.lockedByPID but got \(error)")
                }
            }

            try await existingLock.unlock()
        }
    }

    @Test("waitForLock succeeds when lock becomes available")
    func testWaitForLockEventualSuccess() async throws {
        try await SwiftlyTests.withTestHome {
            let lockPath = SwiftlyTests.ctx.mockedHomeDir! / "eventual.lock"

            // Create initial lock
            let initialLock = try FileLock(at: lockPath)
            // Start waiting for lock in background task
            let waitTask = Task {
                try await Task.sleep(for: .seconds(0.1))
                let waitingLock = try await FileLock.waitForLock(
                    lockPath,
                    timeout: 2.0,
                    pollingInterval: 0.1
                )
                try await waitingLock.unlock()
                return true
            }
            // Release initial lock after delay
            try await Task.sleep(for: .seconds(0.3))
            try await initialLock.unlock()
            // Wait for the waiting task to complete
            let result = try await waitTask.value
            #expect(result, "Lock wait operation should succeed")
        }
    }

    @Test("withLock executes action and automatically unlocks")
    func testWithLockSuccess() async throws {
        try await SwiftlyTests.withTestHome {
            let lockPath = SwiftlyTests.ctx.mockedHomeDir! / "withlock.lock"
            var actionExecuted = false

            let result = try await withLock(lockPath, timeout: 1.0, pollingInterval: 0.1) {
                actionExecuted = true
                return "success"
            }

            #expect(actionExecuted)
            #expect(result == "success")
            #expect(!(try await fs.exists(atPath: lockPath)))
        }
    }

    @Test("withLock unlocks even when action throws")
    func testWithLockErrorHandling() async throws {
        try await SwiftlyTests.withTestHome {
            let lockPath = SwiftlyTests.ctx.mockedHomeDir! / "withlockError.lock"

            struct TestError: Error {}

            await #expect(throws: TestError.self) {
                try await withLock(lockPath, timeout: 1.0, pollingInterval: 0.1) {
                    throw TestError()
                }
            }

            // Lock should be released even after error
            let exists = try await fs.exists(atPath: lockPath)
            #expect(!exists)
        }
    }

    @Test("withLock fails when lock cannot be acquired within timeout")
    func testWithLockTimeout() async throws {
        try await SwiftlyTests.withTestHome {
            let lockPath = SwiftlyTests.ctx.mockedHomeDir! / "withlockTimeout.lock"

            // Create existing lock
            let existingLock = try FileLock(at: lockPath)

            await #expect(throws: SwiftlyError.self) {
                try await withLock(lockPath, timeout: 0.5, pollingInterval: 0.1) {
                    "should not execute"
                }
            }

            try await existingLock.unlock()
        }
    }
}
