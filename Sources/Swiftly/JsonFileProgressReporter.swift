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
    private let ctx: SwiftlyCoreContext
    private let fileHandle: FileHandle

    init(_ ctx: SwiftlyCoreContext, filePath: FilePath, encoder: JSONEncoder = JSONEncoder()) throws
    {
        self.ctx = ctx
        self.filePath = filePath
        self.encoder = encoder
        self.fileHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: filePath.string))
    }

    private func writeProgress(_ progress: ProgressInfo) {
        let jsonData = try? self.encoder.encode(progress)
        guard let jsonData = jsonData else {
            Task { [ctx = self.ctx] in
                await ctx.message("Failed to encode progress entry to JSON")
            }
            return
        }

        self.fileHandle.seekToEndOfFile()
        self.fileHandle.write(jsonData)
        self.fileHandle.write("\n".data(using: .utf8) ?? Data())
        self.fileHandle.synchronizeFile()
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
        self.fileHandle.truncateFile(atOffset: 0)
        self.fileHandle.synchronizeFile()
    }

    func close() throws {
        try self.fileHandle.close()
    }
}
