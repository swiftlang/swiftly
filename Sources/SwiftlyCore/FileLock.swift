import Foundation
import SystemPackage

enum FileLockError: Error {
    case cannotAcquireLock
    case timeoutExceeded
}

/// A non-blocking file lock implementation using file creation as locking mechanism.
/// Use case: When installing multiple Swiftly instances on the same machine,
/// one should acquire the lock while others poll until it becomes available.
public struct FileLock {
    let filePath: FilePath

    public static let defaultPollingInterval: TimeInterval = 1
    public static let defaultTimeout: TimeInterval = 300.0

    public init(at path: FilePath) throws {
        self.filePath = path
        do {
            let fileURL = URL(fileURLWithPath: self.filePath.string)
            let contents = Foundation.ProcessInfo.processInfo.processIdentifier.description.data(using: .utf8) ?? Data()
            try contents.write(to: fileURL, options: .withoutOverwriting)
        } catch CocoaError.fileWriteFileExists {
            throw FileLockError.cannotAcquireLock
        }
    }

    public static func waitForLock(
        _ path: FilePath,
        timeout: TimeInterval = FileLock.defaultTimeout,
        pollingInterval: TimeInterval = FileLock.defaultPollingInterval
    ) async throws -> FileLock {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if let fileLock = try? FileLock(at: path) {
                return fileLock
            }
            try? await Task.sleep(for: .seconds(pollingInterval))
        }

        throw FileLockError.timeoutExceeded
    }

    public func unlock() async throws {
        try await FileSystem.remove(atPath: self.filePath)
    }
}

public func withLock<T>(
    _ lockFile: FilePath,
    timeout: TimeInterval = FileLock.defaultTimeout,
    pollingInterval: TimeInterval = FileLock.defaultPollingInterval,
    action: @escaping () async throws -> T
) async throws -> T {
    guard
        let lock = try? await FileLock.waitForLock(
            lockFile,
            timeout: timeout,
            pollingInterval: pollingInterval
        )
    else {
        throw SwiftlyError(message: "Failed to acquire file lock at \(lockFile)")
    }

    do {
        let result = try await action()
        try await lock.unlock()
        return result
    } catch {
        try await lock.unlock()
        throw error
    }
}
