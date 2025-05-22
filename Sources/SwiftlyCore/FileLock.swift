import Foundation
import SystemPackage

/**
 * A non-blocking file lock implementation using file creation as locking mechanism.
 * Use case: When installing multiple Swiftly instances on the same machine,
 * one should acquire the lock while others poll until it becomes available.
 */

public actor FileLock {
    let filePath: FilePath
    private var isLocked = false

    public static let defaultPollingInterval: TimeInterval = 1
    public static let defaultTimeout: TimeInterval = 300.0

    public init(at path: FilePath) {
        self.filePath = path
    }

    public func tryLock() async -> Bool {
        do {
            guard !self.isLocked else { return true }

            guard !(try await FileSystem.exists(atPath: self.filePath)) else {
                return false
            }
            // Create the lock file with exclusive permissions
            try await FileSystem.create(.mode(0o600), file: self.filePath, contents: nil)
            self.isLocked = true
            return true
        } catch {
            return false
        }
    }

    public func waitForLock(
        timeout: TimeInterval = FileLock.defaultTimeout,
        pollingInterval: TimeInterval = FileLock.defaultPollingInterval
    ) async -> Bool {
        let start = Date()

        while Date().timeIntervalSince(start) < timeout {
            if await self.tryLock() {
                return true
            }
            try? await Task.sleep(for: .seconds(pollingInterval))
        }

        return false
    }

    public func unlock() async throws {
        guard self.isLocked else { return }

        try await FileSystem.remove(atPath: self.filePath)
        self.isLocked = false
    }
}

public func withLock<T>(
    _ lockFile: FilePath,
    timeout: TimeInterval = FileLock.defaultTimeout,
    pollingInterval: TimeInterval = FileLock.defaultPollingInterval,
    action: @escaping () async throws -> T
) async throws -> T {
    let lock = FileLock(at: lockFile)
    guard await lock.waitForLock(timeout: timeout, pollingInterval: pollingInterval) else {
        throw SwiftlyError(message: "Failed to acquire file lock at \(lock.filePath)")
    }

    defer {
        Task {
            do {
                try await lock.unlock()
            } catch {
                print("WARNING: Failed to unlock file: \(error)")
            }
        }
    }

    return try await action()
}
