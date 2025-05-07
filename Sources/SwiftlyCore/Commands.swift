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

extension SystemCommand {
    // OpenPGP encryption and signing tool
    // See gpg(1) for more information.
    public static func gpg(executable: Executable = GpgCommand.defaultExecutable) -> GpgCommand {
        GpgCommand(executable: executable)
    }

    public struct GpgCommand {
        public static var defaultExecutable: Executable { .name("gpg") }

        public var executable: Executable

        public init(executable: Executable) {
            self.executable = executable
        }

        public func config() -> Configuration {
            var args: [String] = []

            return Configuration(
                executable: self.executable,
                arguments: Arguments(args),
                environment: .inherit
            )
        }

        public func _import(keys: FilePath...) -> ImportCommand {
            self._import(keys: keys)
        }

        public func _import(keys: [FilePath]) -> ImportCommand {
            ImportCommand(self, keys: keys)
        }

        public struct ImportCommand {
            public var gpg: GpgCommand

            public var keys: [FilePath]

            public init(_ gpg: GpgCommand, keys: [FilePath]) {
                self.gpg = gpg
                self.keys = keys
            }

            public func config() -> Configuration {
                var c: Configuration = self.gpg.config()

                var args = c.arguments.storage.map(\.description)

                args.append("--import")

                for key in self.keys {
                    args.append("\(key)")
                }

                c.arguments = .init(args)

                return c
            }
        }

        public func verify(detachedSignature: FilePath, signedData: FilePath) -> VerifyCommand {
            VerifyCommand(self, detachedSignature: detachedSignature, signedData: signedData)
        }

        public struct VerifyCommand {
            public var gpg: GpgCommand

            public var detachedSignature: FilePath

            public var signedData: FilePath

            public init(_ gpg: GpgCommand, detachedSignature: FilePath, signedData: FilePath) {
                self.gpg = gpg
                self.detachedSignature = detachedSignature
                self.signedData = signedData
            }

            public func config() -> Configuration {
                var c: Configuration = self.gpg.config()

                var args = c.arguments.storage.map(\.description)

                args.append("--verify")

                args.append("\(self.detachedSignature)")
                args.append("\(self.signedData)")

                c.arguments = .init(args)

                return c
            }
        }
    }
}

extension SystemCommand.GpgCommand.ImportCommand: Runnable {}
extension SystemCommand.GpgCommand.VerifyCommand: Runnable {}

extension SystemCommand {
    // Query and manipulate macOS Installer packages and receipts.
    // See pkgutil(1) for more information.
    public static func pkgutil(executable: Executable = PkgutilCommand.defaultExecutable, _ options: PkgutilCommand.Option...) -> PkgutilCommand {
        Self.pkgutil(executable: executable, options)
    }

    // Query and manipulate macOS Installer packages and receipts.
    // See pkgutil(1) for more information.
    public static func pkgutil(executable: Executable = PkgutilCommand.defaultExecutable, _ options: [PkgutilCommand.Option]) -> PkgutilCommand {
        PkgutilCommand(executable: executable, options)
    }

    public struct PkgutilCommand {
        public static var defaultExecutable: Executable { .name("pkgutil") }

        public var executable: Executable

        public var options: [Option]

        public enum Option {
            case verbose
            case volume(FilePath)

            public func args() -> [String] {
                switch self {
                case .verbose:
                    ["--verbose"]
                case let .volume(volume):
                    ["--volume", "\(volume)"]
                }
            }
        }

        public init(executable: Executable, _ options: [Option]) {
            self.executable = executable
            self.options = options
        }

        public func config() -> Configuration {
            var args: [String] = []

            for opt in self.options {
                args.append(contentsOf: opt.args())
            }

            return Configuration(
                executable: self.executable,
                arguments: Arguments(args),
                environment: .inherit
            )
        }

        public func checkSignature(pkgPath: FilePath) -> CheckSignatureCommand {
            CheckSignatureCommand(self, pkgPath: pkgPath)
        }

        public struct CheckSignatureCommand {
            public var pkgutil: PkgutilCommand

            public var pkgPath: FilePath

            public init(_ pkgutil: PkgutilCommand, pkgPath: FilePath) {
                self.pkgutil = pkgutil
                self.pkgPath = pkgPath
            }

            public func config() -> Configuration {
                var c: Configuration = self.pkgutil.config()

                var args = c.arguments.storage.map(\.description)

                args.append("--check-signature")

                args.append("\(self.pkgPath)")

                c.arguments = .init(args)

                return c
            }
        }

        public func expand(pkgPath: FilePath, dirPath: FilePath) -> ExpandCommand {
            ExpandCommand(self, pkgPath: pkgPath, dirPath: dirPath)
        }

        public struct ExpandCommand {
            public var pkgutil: PkgutilCommand

            public var pkgPath: FilePath

            public var dirPath: FilePath

            public init(_ pkgutil: PkgutilCommand, pkgPath: FilePath, dirPath: FilePath) {
                self.pkgutil = pkgutil
                self.pkgPath = pkgPath
                self.dirPath = dirPath
            }

            public func config() -> Configuration {
                var c: Configuration = self.pkgutil.config()

                var args = c.arguments.storage.map(\.description)

                args.append("--expand")

                args.append("\(self.pkgPath)")

                args.append("\(self.dirPath)")

                c.arguments = .init(args)

                return c
            }
        }

        public func forget(packageId: String) -> ForgetCommand {
            ForgetCommand(self, packageId: packageId)
        }

        public struct ForgetCommand {
            public var pkgutil: PkgutilCommand

            public var packageId: String

            public init(_ pkgutil: PkgutilCommand, packageId: String) {
                self.pkgutil = pkgutil
                self.packageId = packageId
            }

            public func config() -> Configuration {
                var c: Configuration = self.pkgutil.config()

                var args = c.arguments.storage.map(\.description)

                args.append("--forget")

                args.append("\(self.packageId)")

                c.arguments = .init(args)

                return c
            }
        }
    }
}

extension SystemCommand.PkgutilCommand.CheckSignatureCommand: Runnable {}
extension SystemCommand.PkgutilCommand.ExpandCommand: Runnable {}
extension SystemCommand.PkgutilCommand.ForgetCommand: Runnable {}

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
