import Foundation
import ArgumentParser

public protocol ProgressReporter {
    func update(step: Int, total: Int, text: String?)
    func complete(success: Bool)
}

struct ProgressMessage: Codable {
    let type: String
    let receivedBytes: Int
    let totalBytes: Int
    let text: String?
}

public struct JSONLineProgressReporter: ProgressReporter {
    public init() {}

    public func update(step: Int, total: Int, text: String?) {
        var payload: [String: Any] = [
            "type": "progress",
            "receivedBytes": step,
            "totalBytes": total,
        ]
        if let text {
            payload["text"] = text
        }
        if let data = try? JSONSerialization.data(withJSONObject: payload),
           let jsonString = String(data: data, encoding: .utf8)
        {
            print(jsonString)
        }
    }

    public func complete(success: Bool) {
        let payload: [String: Any] = [
            "type": "complete",
            "success": success,
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload),
           let jsonString = String(data: data, encoding: .utf8)
        {
            print(jsonString)
        }
    }
}

public struct PercentProgressReporter: ProgressReporter {
    public init() {}

    public func update(step: Int, total: Int, text: String?) {
        let percent = Double(step) / Double(total) * 100
        let text = text ?? ""
        print("\(percent)% \(text)")
    }

    public func complete(success: Bool) {
        print("Complete: \(success ? "Success" : "Failure")")
    }
}
