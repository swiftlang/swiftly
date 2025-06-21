import Foundation
import SwiftlyCore
import SystemPackage
import TSCUtility

enum ProgressInfo: Codable {
    case step(timestamp: Date, percent: Int, text: String)
    case complete(success: Bool)
}

struct JsonFileProgressReporter: ProgressAnimationProtocol {
    let filePath: FilePath
    private let encoder: JSONEncoder

    init(filePath: FilePath, encoder: JSONEncoder = JSONEncoder()) {
        self.filePath = filePath
        self.encoder = encoder
    }

    private func writeProgress(_ progress: ProgressInfo) {
        let jsonData = try? self.encoder.encode(progress)
        guard let jsonData = jsonData, let jsonString = String(data: jsonData, encoding: .utf8)
        else {
            print("Failed to encode progress entry to JSON")
            return
        }

        let jsonLine = jsonString + "\n"

        do {
            try jsonLine.append(to: self.filePath)
        } catch {
            print("Failed to write progress entry to \(self.filePath): \(error)")
        }
    }

    func update(step: Int, total: Int, text: String) {
        assert(step <= total)
        self.writeProgress(
            ProgressInfo.step(
                timestamp: Date(),
                percent: Int(Double(step) / Double(total) * 100),
                text: text
            ))
    }

    func complete(success: Bool) {
        self.writeProgress(ProgressInfo.complete(success: success))
    }

    func clear() {
        do {
            try FileManager.default.removeItem(atPath: self.filePath.string)
        } catch {
            print("Failed to clear progress file at \(self.filePath): \(error)")
        }
    }
}
