import Foundation

#if os(Windows)
import WinSDK
#endif

enum ProcessCheckError: Error {
    case invalidPID
    case checkFailed
}

/// Checks if a process is still running by process ID
/// - Parameter pidString: The process ID
/// - Returns: true if the process is running, false if it's not running or doesn't exist
/// - Throws: ProcessCheckError if the check fails or PID is invalid
public func isProcessRunning(pidString: String) throws -> Bool {
    guard let pid = Int32(pidString.trimmingCharacters(in: .whitespaces)) else {
        throw ProcessCheckError.invalidPID
    }

    return try isProcessRunning(pid: pid)
}

public func isProcessRunning(pid: Int32) throws -> Bool {
#if os(macOS) || os(Linux)
    let result = kill(pid, 0)
    if result == 0 {
        return true
    } else if errno == ESRCH { // No such process
        return false
    } else if errno == EPERM { // Operation not permitted, but process exists
        return true
    } else {
        throw ProcessCheckError.checkFailed
    }

#elseif os(Windows)
    // On Windows, use OpenProcess to check if process exists
    let handle = OpenProcess(DWORD(PROCESS_QUERY_LIMITED_INFORMATION), false, DWORD(pid))
    if handle != nil {
        CloseHandle(handle)
        return true
    } else {
        let error = GetLastError()
        if error == ERROR_INVALID_PARAMETER || error == ERROR_NOT_FOUND {
            return false // Process not found
        } else {
            throw ProcessCheckError.checkFailed
        }
    }

#else
    #error("Platform is not supported")
#endif
}
