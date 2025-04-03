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

public func promptForConfirmation(_ ctx: SwiftlyCoreContext, defaultBehavior: Bool) -> Bool {
    let options: String
    if defaultBehavior {
        options = "(Y/n)"
    } else {
        options = "(y/N)"
    }

    while true {
        let answer = (SwiftlyCore.readLine(ctx, prompt: "Proceed? \(options)") ?? (defaultBehavior ? "y" : "n")).lowercased()

        guard ["y", "n", ""].contains(answer) else {
            SwiftlyCore.print(ctx, "Please input either \"y\" or \"n\", or press ENTER to use the default.")
            continue
        }

        if answer.isEmpty {
            return defaultBehavior
        } else {
            return answer == "y"
        }
    }
}
