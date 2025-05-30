import Foundation
import SystemPackage

enum FileLockError: Error, LocalizedError {
    case cannotAcquireLock(FilePath)
    case lockedByPID(FilePath, String)

    var errorDescription: String? {
        switch self {
        case let .cannotAcquireLock(path):
            return "Cannot acquire lock at \(path). Another process may be holding the lock. If you are sure no other processes are running, you can manually remove the lock file at \(path)."
        case let .lockedByPID(path, pid):
            return
                "Lock at \(path) is held by process ID \(pid). Wait for the process to complete or manually remove the lock file if the process is no longer running."
        }
    }
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
            let contents = Foundation.ProcessInfo.processInfo.processIdentifier.description.data(using: .utf8)
                ?? Data()
            try contents.write(to: fileURL, options: .withoutOverwriting)
        } catch CocoaError.fileWriteFileExists {
            // Read the PID from the existing lock file
            let fileURL = URL(fileURLWithPath: self.filePath.string)
            if let data = try? Data(contentsOf: fileURL),
               let pidString = String(data: data, encoding: .utf8)?.trimmingCharacters(
                   in: .whitespacesAndNewlines),
               !pidString.isEmpty
            {
                throw FileLockError.lockedByPID(self.filePath, pidString)
            } else {
                throw FileLockError.cannotAcquireLock(self.filePath)
            }
        }
    }

    public static func waitForLock(
        _ path: FilePath,
        timeout: TimeInterval = FileLock.defaultTimeout,
        pollingInterval: TimeInterval = FileLock.defaultPollingInterval
    ) async throws -> FileLock {
        let start = Date()
        var lastError: Error?

        while Date().timeIntervalSince(start) < timeout {
            let result = Result { try FileLock(at: path) }

            switch result {
            case let .success(lock):
                return lock
            case let .failure(error):
                lastError = error
                try? await Task.sleep(for: .seconds(pollingInterval) + .milliseconds(Int.random(in: 0...200)))
            }
        }

        // Timeout reached, throw the last error from the loop
        if let lastError = lastError {
            throw lastError
        } else {
            throw FileLockError.cannotAcquireLock(path)
        }
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
    let lock: FileLock
    do {
        lock = try await FileLock.waitForLock(
            lockFile,
            timeout: timeout,
            pollingInterval: pollingInterval
        )
    } catch {
        throw SwiftlyError(message: "Failed to acquire file lock at \(lockFile): \(error.localizedDescription)")
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
