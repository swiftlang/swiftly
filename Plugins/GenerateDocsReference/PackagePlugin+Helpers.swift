import Foundation
import PackagePlugin

extension ArgumentExtractor {
    mutating func helpRequest() -> Bool {
        self.extractFlag(named: "help") > 0
    }

    mutating func configuration() throws -> PackageManager.BuildConfiguration {
        switch self.extractOption(named: "configuration").first {
        case let .some(configurationString):
            switch configurationString {
            case "debug":
                return .debug
            case "release":
                return .release
            default:
                throw
                    GenerateDocsReferencePluginError
                    .unknownBuildConfiguration(configurationString)
            }
        case .none:
            return .release
        }
    }
}

extension URL {
    func exec(arguments: [String]) throws {
        do {
            let process = Process()
            process.executableURL = self
            process.arguments = arguments
            try process.run()
            process.waitUntilExit()
            guard
                process.terminationReason == .exit,
                process.terminationStatus == 0
            else {
                throw GenerateDocsReferencePluginError.subprocessFailedNonZeroExit(
                    self, process.terminationStatus
                )
            }
        } catch {
            throw GenerateDocsReferencePluginError.subprocessFailedError(self, error)
        }
    }
}

extension Product {
    func hasDependency(named name: String) -> Bool {
        self.recursiveTargetDependencies
            .contains { $0.name == name }
    }

    var recursiveTargetDependencies: [Target] {
        var dependencies = [Target.ID: Target]()
        for target in self.targets {
            for dependency in target.recursiveTargetDependencies {
                dependencies[dependency.id] = dependency
            }
        }
        return Array(dependencies.values)
    }
}
