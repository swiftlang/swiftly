import Foundation

/**
 * A non-blocking file lock implementation with polling capability.
 * Use case: When installing multiple Swiftly instances on the same machine,
 * one should acquire the lock while others poll until it becomes available.
 */

#if os(macOS)
    import Darwin.C
#elseif os(Linux)
    import Glibc
#endif

public struct FileLock {
    let filePath: String

    let fileHandle: FileHandle

    public static let defaultPollingInterval: TimeInterval = 1.0

    public static let defaultTimeout: TimeInterval = 300.0

    public init(at filePath: String) throws {
        self.filePath = filePath

        if !FileManager.default.fileExists(atPath: filePath) {
            FileManager.default.createFile(atPath: filePath, contents: nil)
        }

        self.fileHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: filePath))
    }

    public func tryLock() -> Bool {
        return self.fileHandle.tryLockFile()
    }

    public func waitForLock(
        timeout: TimeInterval = FileLock.defaultTimeout,
        pollingInterval: TimeInterval = FileLock.defaultPollingInterval
    ) -> Bool {
        let startTime = Date()

        if tryLock() {
            return true
        }

        while Date().timeIntervalSince(startTime) < timeout {
            // Sleep for the polling interval
            Thread.sleep(forTimeInterval: pollingInterval)

            // Try to acquire the lock
            if tryLock() {
                return true
            }
        }

        // Timed out without acquiring the lock
        return false
    }

    public func unlock() throws {
        try self.fileHandle.unlockFile()
        try fileHandle.close()
    }
}

extension FileHandle {

    func tryLockFile() -> Bool {
        let fd = self.fileDescriptor
        var flock = flock()
        flock.l_type = Int16(F_WRLCK)
        flock.l_whence = Int16(SEEK_SET)
        flock.l_start = 0
        flock.l_len = 0

        // Fails immediately if lock can't be acquired
        if fcntl(fd, F_SETLK, &flock) == -1 {
            if errno == EACCES || errno == EAGAIN {
                return false
            } else {
                fputs("Unexpected lock error: \(String(cString: strerror(errno)))\n", stderr)
                Foundation.exit(1)
            }
        }
        return true
    }

    func unlockFile() throws {
        let fd = self.fileDescriptor
        var flock = flock()
        flock.l_type = Int16(F_UNLCK)
        flock.l_whence = Int16(SEEK_SET)
        flock.l_start = 0
        flock.l_len = 0

        if fcntl(fd, F_SETLK, &flock) == -1 {
            throw SwiftlyError(
                message: "Failed to unlock file: \(String(cString: strerror(errno)))")
        }
    }
}
