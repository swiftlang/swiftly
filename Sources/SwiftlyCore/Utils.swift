import Foundation

extension URL {
    public func fileExists() -> Bool {
        FileManager.default.fileExists(atPath: self.path, isDirectory: nil)
    }
}
