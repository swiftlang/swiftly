import Foundation
import SystemPackage

// This file contains a set of system commands that's used by Swiftly and its related tests and tooling

extension SystemCommand.dsclCommand.readCommand: Output {
    public func properties(_ p: Platform) async throws -> [(key: String, value: String)] {
        let output = try await self.output(p)
        guard let output else { return [] }

        var props: [(key: String, value: String)] = []
        for line in output.components(separatedBy: "\n") {
            if case let comps = line.components(separatedBy: ": "), comps.count == 2 {
                props.append((key: comps[0], value: comps[1]))
            }
        }
        return props
    }
}

extension SystemCommand.lipoCommand.createCommand: Runnable {}

extension SystemCommand.pkgbuildCommand: Runnable {}

extension SystemCommand.getentCommand: Output {
    public func entries(_ platform: Platform) async throws -> [[String]] {
        let output = try await output(platform)
        guard let output else { return [] }

        var entries: [[String]] = []
        for line in output.components(separatedBy: "\n") {
            entries.append(line.components(separatedBy: ":"))
        }
        return entries
    }
}

extension SystemCommand.gitCommand.logCommand: Output {}
extension SystemCommand.gitCommand.diffindexCommand: Runnable {}
extension SystemCommand.gitCommand.initCommand: Runnable {}
extension SystemCommand.gitCommand.commitCommand: Runnable {}

extension SystemCommand.tarCommand.createCommand: Runnable {}
extension SystemCommand.tarCommand.extractCommand: Runnable {}

extension SystemCommand.swiftCommand.packageCommand.resetCommand: Runnable {}
extension SystemCommand.swiftCommand.packageCommand.cleanCommand: Runnable {}
extension SystemCommand.swiftCommand.packageCommand.initCommand: Runnable {}
extension SystemCommand.swiftCommand.sdkCommand.installCommand: Runnable {}
extension SystemCommand.swiftCommand.sdkCommand.removeCommand: Runnable {}
extension SystemCommand.swiftCommand.buildCommand: Runnable {}

extension SystemCommand.makeCommand: Runnable {}
extension SystemCommand.makeCommand.installCommand: Runnable {}

extension SystemCommand.stripCommand: Runnable {}

extension SystemCommand.sha256sumCommand: Output {}

extension SystemCommand.productbuildCommand: Runnable {}

extension SystemCommand.gpgCommand.importCommand: Runnable {}
extension SystemCommand.gpgCommand.verifyCommand: Runnable {}

extension SystemCommand.pkgutilCommand.checksignatureCommand: Runnable {}
extension SystemCommand.pkgutilCommand.expandCommand: Runnable {}
extension SystemCommand.pkgutilCommand.forgetCommand: Runnable {}

extension SystemCommand {
    // system software and package installer tool.
    // See installer(1) for more information
    public static func installer(executable: Executable = InstallerCommand.defaultExecutable, _ options: InstallerCommand.Option..., pkg: FilePath, target: String) -> InstallerCommand {
        self.installer(executable: executable, options, pkg: pkg, target: target)
    }

    public static func installer(executable: Executable = InstallerCommand.defaultExecutable, _ options: [InstallerCommand.Option], pkg: FilePath, target: String) -> InstallerCommand {
        InstallerCommand(executable: executable, options, pkg: pkg, target: target)
    }

    public struct InstallerCommand {
        public static var defaultExecutable: Executable { .name("installer") }

        public var executable: Executable

        public var options: [Option]

        public var pkg: FilePath

        public var target: String

        public enum Option {
            case verbose

            public func args() -> [String] {
                switch self {
                case .verbose:
                    ["-verbose"]
                }
            }
        }

        public init(executable: Executable, _ options: [Option], pkg: FilePath, target: String) {
            self.executable = executable
            self.options = options
            self.pkg = pkg
            self.target = target
        }

        public func config() -> Configuration {
            var args: [String] = []

            for opt in self.options {
                args.append(contentsOf: opt.args())
            }

            args.append(contentsOf: ["-pkg", "\(self.pkg)"])
            args.append(contentsOf: ["-target", self.target])

            return Configuration(
                executable: self.executable,
                arguments: Arguments(args),
                environment: .inherit
            )
        }
    }
}

extension SystemCommand.InstallerCommand: Runnable {}
