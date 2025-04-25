import Foundation
import SystemPackage

public enum SystemCommand {}

// This file contains a set of system commands that's used by Swiftly and its related tests and tooling

// Directory Service command line utility for macOS
// See dscl(1) for details
extension SystemCommand {
    public static func dscl(executable: Executable = DsclCommand.defaultExecutable, datasource: String? = nil) -> DsclCommand {
        DsclCommand(executable: executable, datasource: datasource)
    }

    public struct DsclCommand {
        public static var defaultExecutable: Executable { .name("dscl") }

        var executable: Executable
        var datasource: String?

        internal init(
            executable: Executable,
            datasource: String?
        ) {
            self.executable = executable
            self.datasource = datasource
        }

        func config() -> Configuration {
            var args: [String] = []

            if let datasource = self.datasource {
                args += [datasource]
            }

            return Configuration(
                executable: self.executable,
                arguments: Arguments(args),
                environment: .inherit
            )
        }

        public func read(path: FilePath? = nil, keys: [String]) -> ReadCommand {
            ReadCommand(dscl: self, path: path, keys: keys)
        }

        public func read(path: FilePath? = nil, keys: String...) -> ReadCommand {
            self.read(path: path, keys: keys)
        }

        public struct ReadCommand {
            var dscl: DsclCommand
            var path: FilePath?
            var keys: [String]

            internal init(dscl: DsclCommand, path: FilePath?, keys: [String]) {
                self.dscl = dscl
                self.path = path
                self.keys = keys
            }

            public func config() -> Configuration {
                var c = self.dscl.config()

                var args = c.arguments.storage.map(\.description) + ["-read"]

                if let path = self.path {
                    args += [path.string] + self.keys
                }

                c.arguments = .init(args)

                return c
            }
        }
    }
}

extension SystemCommand.DsclCommand.ReadCommand: Output {
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

// Create or operate on universal files
// See lipo(1) for details
extension SystemCommand {
    public static func lipo(executable: Executable = LipoCommand.defaultExecutable, inputFiles: FilePath...) -> LipoCommand {
        Self.lipo(executable: executable, inputFiles: inputFiles)
    }

    public static func lipo(executable: Executable = LipoCommand.defaultExecutable, inputFiles: [FilePath]) -> LipoCommand {
        LipoCommand(executable: executable, inputFiles: inputFiles)
    }

    public struct LipoCommand {
        public static var defaultExecutable: Executable { .name("lipo") }

        var executable: Executable
        var inputFiles: [FilePath]

        internal init(executable: Executable, inputFiles: [FilePath]) {
            self.executable = executable
            self.inputFiles = inputFiles
        }

        func config() -> Configuration {
            var args: [String] = []

            args += self.inputFiles.map(\.string)

            return Configuration(
                executable: self.executable,
                arguments: Arguments(args),
                environment: .inherit
            )
        }

        public func create(output: FilePath) -> CreateCommand {
            CreateCommand(self, output: output)
        }

        public struct CreateCommand {
            var lipo: LipoCommand
            var output: FilePath

            init(_ lipo: LipoCommand, output: FilePath) {
                self.lipo = lipo
                self.output = output
            }

            public func config() -> Configuration {
                var c = self.lipo.config()

                var args = c.arguments.storage.map(\.description) + ["-create", "-output", "\(self.output)"]

                c.arguments = .init(args)

                return c
            }
        }
    }
}

extension SystemCommand.LipoCommand.CreateCommand: Runnable {}

// Build a macOS Installer component package from on-disk files
// See pkgbuild(1) for more details
extension SystemCommand {
    public static func pkgbuild(executable: Executable = PkgbuildCommand.defaultExecutable, _ options: PkgbuildCommand.Option..., root: FilePath, packageOutputPath: FilePath) -> PkgbuildCommand {
        Self.pkgbuild(executable: executable, options: options, root: root, packageOutputPath: packageOutputPath)
    }

    public static func pkgbuild(executable: Executable = PkgbuildCommand.defaultExecutable, options: [PkgbuildCommand.Option], root: FilePath, packageOutputPath: FilePath) -> PkgbuildCommand {
        PkgbuildCommand(executable: executable, options, root: root, packageOutputPath: packageOutputPath)
    }

    public struct PkgbuildCommand {
        public static var defaultExecutable: Executable { .name("pkgbuild") }

        var executable: Executable

        var options: [Option]

        var root: FilePath
        var packageOutputPath: FilePath

        internal init(executable: Executable, _ options: [Option], root: FilePath, packageOutputPath: FilePath) {
            self.executable = executable
            self.options = options
            self.root = root
            self.packageOutputPath = packageOutputPath
        }

        public enum Option {
            case installLocation(FilePath)
            case version(String)
            case identifier(String)
            case sign(String)

            func args() -> [String] {
                switch self {
                case let .installLocation(installLocation):
                    return ["--install-location", installLocation.string]
                case let .version(version):
                    return ["--version", version]
                case let .identifier(identifier):
                    return ["--identifier", identifier]
                case let .sign(identityName):
                    return ["--sign", identityName]
                }
            }
        }

        public func config() -> Configuration {
            var args: [String] = []

            for option in self.options {
                args += option.args()
            }

            args += ["--root", "\(self.root)"]
            args += ["\(self.packageOutputPath)"]

            return Configuration(
                executable: self.executable,
                arguments: Arguments(args),
                environment: .inherit
            )
        }
    }
}

extension SystemCommand.PkgbuildCommand: Runnable {}

// get entries from Name Service Switch libraries
// See getent(1) for more details
extension SystemCommand {
    public static func getent(executable: Executable = GetentCommand.defaultExecutable, database: String, keys: String...) -> GetentCommand {
        Self.getent(executable: executable, database: database, keys: keys)
    }

    public static func getent(executable: Executable = GetentCommand.defaultExecutable, database: String, keys: [String]) -> GetentCommand {
        GetentCommand(executable: executable, database: database, keys: keys)
    }

    public struct GetentCommand {
        public static var defaultExecutable: Executable { .name("getent") }

        var executable: Executable

        var database: String

        var keys: [String]

        internal init(
            executable: Executable,
            database: String,
            keys: [String]
        ) {
            self.executable = executable
            self.database = database
            self.keys = keys
        }

        public func config() -> Configuration {
            var args: [String] = []

            args += [self.database]
            args += self.keys

            return Configuration(
                executable: self.executable,
                arguments: Arguments(args),
                environment: .inherit
            )
        }
    }
}

extension SystemCommand.GetentCommand: Output {
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
