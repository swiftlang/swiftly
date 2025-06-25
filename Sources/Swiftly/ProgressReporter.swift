import Foundation
import SwiftlyCore
import SystemPackage
import TSCBasic
import TSCUtility

public protocol ProgressReporterProtocol {
    /// Updates the progress animation with the current step, total steps, and an optional text message.
    func update(step: Int, total: Int, text: String) async

    /// Completes the progress animation, indicating success or failure.
    func complete(success: Bool) async

    /// Closes any resources used by the reporter, if applicable.
    func close() throws
}

/// Progress reporter that delegates to a `PercentProgressAnimation` for console output.
struct ConsoleProgressReporter: ProgressReporterProtocol {
    private let reporter: PercentProgressAnimation

    init(stream: WritableByteStream, header: String) {
        self.reporter = PercentProgressAnimation(stream: stream, header: header)
    }

    func update(step: Int, total: Int, text: String) async {
        self.reporter.update(step: step, total: total, text: text)
    }

    func complete(success: Bool) async {
        self.reporter.complete(success: success)
    }

    func close() {
        // No resources to close for console reporter
    }
}

enum ProgressInfo: Codable {
    case step(timestamp: Date, percent: Int, text: String)
    case complete(success: Bool)
}

struct JsonFileProgressReporter: ProgressReporterProtocol {
    let filePath: FilePath
    private let encoder: JSONEncoder
    private let ctx: SwiftlyCoreContext
    private let fileHandle: FileHandle

    init(_ ctx: SwiftlyCoreContext, filePath: FilePath, encoder: JSONEncoder = JSONEncoder()) throws
    {
        self.ctx = ctx
        self.filePath = filePath
        self.encoder = encoder
        self.fileHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: filePath.string))
    }

    private func writeProgress(_ progress: ProgressInfo) async {
        let jsonData = try? self.encoder.encode(progress)
        guard let jsonData = jsonData else {
            await self.ctx.message("Failed to encode progress entry to JSON")
            return
        }

        self.fileHandle.write(jsonData)
        self.fileHandle.write("\n".data(using: .utf8) ?? Data())
        try? self.fileHandle.synchronize()
    }

    func update(step: Int, total: Int, text: String) async {
        guard total > 0 && step <= total else {
            return
        }
        await self.writeProgress(
            ProgressInfo.step(
                timestamp: Date(),
                percent: Int(Double(step) / Double(total) * 100),
                text: text
            )
        )
    }

    func complete(success: Bool) async {
        await self.writeProgress(ProgressInfo.complete(success: success))
    }

    func close() throws {
        try self.fileHandle.close()
    }
}
