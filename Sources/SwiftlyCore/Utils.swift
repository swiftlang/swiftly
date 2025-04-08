import Foundation

extension URL {
    public func fileExists() -> Bool {
        FileManager.default.fileExists(atPath: self.path, isDirectory: nil)
    }

    public func deleteIfExists() throws {
        do {
            try FileManager.default.removeItem(at: self)
        } catch let error as NSError {
            guard error.domain == NSCocoaErrorDomain && error.code == CocoaError.fileNoSuchFile.rawValue else {
                throw error
            }
        }
    }
}
