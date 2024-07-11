import Foundation
import PackagePlugin

enum GenerateDocsReferencePluginError: Error {
    case unknownBuildConfiguration(String)
    case buildFailed(String)
    case createOutputDirectoryFailed(Error)
    case subprocessFailedNonZeroExit(Path, Int32)
    case subprocessFailedError(Path, Error)
}

extension GenerateDocsReferencePluginError: CustomStringConvertible {
    var description: String {
        switch self {
        case .unknownBuildConfiguration(let configuration):
            return "Build failed: Unknown build configuration '\(configuration)'."
        case .buildFailed(let logText):
            return "Build failed: \(logText)."
        case .createOutputDirectoryFailed(let error):
            return """
                Failed to create output directory: '\(error.localizedDescription)'
                """
        case .subprocessFailedNonZeroExit(let tool, let exitCode):
            return """
                '\(tool.lastComponent)' invocation failed with a nonzero exit code: \
                '\(exitCode)'.
                """
        case .subprocessFailedError(let tool, let error):
            return """
                '\(tool.lastComponent)' invocation failed: \
                '\(error.localizedDescription)'
                """
        }
    }
}

extension GenerateDocsReferencePluginError: LocalizedError {
    var errorDescription: String? { self.description }
}
