import Foundation
@preconcurrency import PackagePlugin

@preconcurrency
enum GenerateDocsReferencePluginError: Error {
    case unknownBuildConfiguration(String)
    case buildFailed(String)
    case createOutputDirectoryFailed(Error)
    case subprocessFailedNonZeroExit(URL, Int32)
    case subprocessFailedError(URL, Error)
}

extension GenerateDocsReferencePluginError: CustomStringConvertible {
    var description: String {
        switch self {
        case let .unknownBuildConfiguration(configuration):
            return "Build failed: Unknown build configuration '\(configuration)'."
        case let .buildFailed(logText):
            return "Build failed: \(logText)."
        case let .createOutputDirectoryFailed(error):
            return """
            Failed to create output directory: '\(error.localizedDescription)'
            """
        case let .subprocessFailedNonZeroExit(tool, exitCode):
            return """
            '\(tool.lastPathComponent)' invocation failed with a nonzero exit code: \
            '\(exitCode)'.
            """
        case let .subprocessFailedError(tool, error):
            return """
            '\(tool.lastPathComponent)' invocation failed: \
            '\(error.localizedDescription)'
            """
        }
    }
}

extension GenerateDocsReferencePluginError: LocalizedError {
    var errorDescription: String? { self.description }
}
