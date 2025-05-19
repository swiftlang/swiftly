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
        self.fileHandle.tryLockFile()
    }

    public func waitForLock(
        timeout: TimeInterval = FileLock.defaultTimeout,
        pollingInterval: TimeInterval = FileLock.defaultPollingInterval
    ) -> Bool {
        let startTime = Date()

        if self.tryLock() {
            return true
        }

        while Date().timeIntervalSince(startTime) < timeout {
            Thread.sleep(forTimeInterval: pollingInterval)

            if self.tryLock() {
                return true
            }
        }

        return false
    }

    public func unlock() throws {
        guard self.fileHandle != nil else { return }
        try self.fileHandle.unlockFile()
        try self.fileHandle.close()
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

        if fcntl(fd, F_SETLK, &flock) == -1 {
            if errno == EACCES || errno == EAGAIN {
                return false
            } else {
                fputs("Unexpected lock error: \(String(cString: strerror(errno)))\n", stderr)
                return false
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
