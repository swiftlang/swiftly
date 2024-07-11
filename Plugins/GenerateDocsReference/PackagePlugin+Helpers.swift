import Foundation
import PackagePlugin

extension ArgumentExtractor {
    mutating func helpRequest() -> Bool {
        self.extractFlag(named: "help") > 0
    }

    mutating func configuration() throws -> PackageManager.BuildConfiguration {
        switch self.extractOption(named: "configuration").first {
        case .some(let configurationString):
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

extension Path {
    func createOutputDirectory() throws {
        do {
            try FileManager.default.createDirectory(
                atPath: self.string,
                withIntermediateDirectories: true)
        } catch {
            throw GenerateDocsReferencePluginError.createOutputDirectoryFailed(error)
        }
    }

    func exec(arguments: [String]) throws {
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: self.string)
            process.arguments = arguments
            try process.run()
            process.waitUntilExit()
            guard
                process.terminationReason == .exit,
                process.terminationStatus == 0
            else {
                throw GenerateDocsReferencePluginError.subprocessFailedNonZeroExit(
                    self, process.terminationStatus)
            }
        } catch {
            throw GenerateDocsReferencePluginError.subprocessFailedError(self, error)
        }
    }
}

extension PackageManager.BuildResult.BuiltArtifact {
    func matchingProduct(context: PluginContext) -> Product? {
        context
            .package
            .products
            .first { $0.name == self.path.lastComponent }
    }
}

extension Product {
    func hasDependency(named name: String) -> Bool {
        recursiveTargetDependencies
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
