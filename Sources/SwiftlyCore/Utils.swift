import Foundation

extension URL {
    public func fileExists() -> Bool {
        return FileManager.default.fileExists(atPath: self.path, isDirectory: nil)
    }
}
