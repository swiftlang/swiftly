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
                args.append(datasource)
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
                    args.append(path.string)
                }

                args.append(contentsOf: self.keys)

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

            args.append(contentsOf: self.inputFiles.map(\.string))

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
                args.append(contentsOf: option.args())
            }

            args.append(contentsOf: ["--root", "\(self.root)"])
            args.append("\(self.packageOutputPath)")

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

            args.append(self.database)
            args.append(contentsOf: self.keys)

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

extension SystemCommand {
    public static func git(executable: Executable = GitCommand.defaultExecutable, workingDir: FilePath? = nil) -> GitCommand {
        GitCommand(executable: executable, workingDir: workingDir)
    }

    public struct GitCommand {
        public static var defaultExecutable: Executable { .name("git") }

        var executable: Executable

        var workingDir: FilePath?

        internal init(executable: Executable, workingDir: FilePath?) {
            self.executable = executable
            self.workingDir = workingDir
        }

        func config() -> Configuration {
            var args: [String] = []

            if let workingDir {
                args.append(contentsOf: ["-C", "\(workingDir)"])
            }

            return Configuration(
                executable: self.executable,
                arguments: Arguments(args),
                environment: .inherit
            )
        }

        public func _init() -> InitCommand {
            InitCommand(self)
        }

        public struct InitCommand {
            var git: GitCommand

            internal init(_ git: GitCommand) {
                self.git = git
            }

            public func config() -> Configuration {
                var c = self.git.config()

                var args = c.arguments.storage.map(\.description)

                args.append("init")

                c.arguments = .init(args)

                return c
            }
        }

        public func commit(_ options: CommitCommand.Option...) -> CommitCommand {
            self.commit(options: options)
        }

        public func commit(options: [CommitCommand.Option]) -> CommitCommand {
            CommitCommand(self, options: options)
        }

        public struct CommitCommand {
            var git: GitCommand

            var options: [Option]

            internal init(_ git: GitCommand, options: [Option]) {
                self.git = git
                self.options = options
            }

            public enum Option {
                case allowEmpty
                case allowEmptyMessage
                case message(String)

                public func args() -> [String] {
                    switch self {
                    case .allowEmpty:
                        ["--allow-empty"]
                    case .allowEmptyMessage:
                        ["--allow-empty-message"]
                    case let .message(message):
                        ["-m", message]
                    }
                }
            }

            public func config() -> Configuration {
                var c = self.git.config()

                var args = c.arguments.storage.map(\.description)

                args.append("commit")
                for option in self.options {
                    args.append(contentsOf: option.args())
                }

                c.arguments = .init(args)

                return c
            }
        }

        public func log(_ options: LogCommand.Option...) -> LogCommand {
            LogCommand(self, options)
        }

        public struct LogCommand {
            var git: GitCommand
            var options: [Option]

            internal init(_ git: GitCommand, _ options: [Option]) {
                self.git = git
                self.options = options
            }

            public enum Option {
                case maxCount(Int)
                case pretty(String)

                func args() -> [String] {
                    switch self {
                    case let .maxCount(num):
                        return ["--max-count=\(num)"]
                    case let .pretty(format):
                        return ["--pretty=\(format)"]
                    }
                }
            }

            public func config() -> Configuration {
                var c = self.git.config()

                var args = c.arguments.storage.map(\.description)

                args.append("log")

                for opt in self.options {
                    args.append(contentsOf: opt.args())
                }

                c.arguments = .init(args)

                return c
            }
        }

        public func diffIndex(_ options: DiffIndexCommand.Option..., treeIsh: String?) -> DiffIndexCommand {
            DiffIndexCommand(self, options, treeIsh: treeIsh)
        }

        public struct DiffIndexCommand {
            var git: GitCommand
            var options: [Option]
            var treeIsh: String?

            internal init(_ git: GitCommand, _ options: [Option], treeIsh: String?) {
                self.git = git
                self.options = options
                self.treeIsh = treeIsh
            }

            public enum Option {
                case quiet

                func args() -> [String] {
                    switch self {
                    case .quiet:
                        return ["--quiet"]
                    }
                }
            }

            public func config() -> Configuration {
                var c = self.git.config()

                var args = c.arguments.storage.map(\.description)

                args.append("diff-index")

                for opt in self.options {
                    args.append(contentsOf: opt.args())
                }

                if let treeIsh = self.treeIsh {
                    args.append(treeIsh)
                }

                c.arguments = .init(args)

                return c
            }
        }
    }
}

extension SystemCommand.GitCommand.LogCommand: Output {}
extension SystemCommand.GitCommand.DiffIndexCommand: Runnable {}
extension SystemCommand.GitCommand.InitCommand: Runnable {}
extension SystemCommand.GitCommand.CommitCommand: Runnable {}

// manipulate tape archives
// See tar(1) for more details
extension SystemCommand {
    public static func tar(executable: Executable = TarCommand.defaultExecutable, _ options: TarCommand.Option...) -> TarCommand {
        Self.tar(executable: executable, options)
    }

    public static func tar(executable: Executable = TarCommand.defaultExecutable, _ options: [TarCommand.Option]) -> TarCommand {
        TarCommand(executable: executable, options)
    }

    public struct TarCommand {
        public static var defaultExecutable: Executable { .name("tar") }

        var executable: Executable

        var options: [Option]

        public init(executable: Executable, _ options: [Option]) {
            self.executable = executable
            self.options = options
        }

        public enum Option {
            case directory(FilePath)

            public func args() -> [String] {
                switch self {
                case let .directory(directory):
                    return ["-C", "\(directory)"] // This is the only portable form between macOS and GNU
                }
            }
        }

        func config() -> Configuration {
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

        public func create(_ options: CreateCommand.Option...) -> CreateCommand {
            self.create(options, files: [])
        }

        public func create(_ options: CreateCommand.Option..., files: FilePath...) -> CreateCommand {
            self.create(options, files: files)
        }

        public func create(_ options: [CreateCommand.Option], files: [FilePath]) -> CreateCommand {
            CreateCommand(self, options, files: files)
        }

        public struct CreateCommand {
            var tar: TarCommand

            var options: [Option]

            var files: [FilePath]

            init(_ tar: TarCommand, _ options: [Option], files: [FilePath]) {
                self.tar = tar
                self.options = options
                self.files = files
            }

            public enum Option {
                case archive(FilePath)
                case compressed
                case verbose

                func args() -> [String] {
                    switch self {
                    case let .archive(archive):
                        return ["--file", "\(archive)"]
                    case .compressed:
                        return ["-z"]
                    case .verbose:
                        return ["-v"]
                    }
                }
            }

            public func config() -> Configuration {
                var c = self.tar.config()

                var args = c.arguments.storage.map(\.description)

                args.append("-c")

                for opt in self.options {
                    args.append(contentsOf: opt.args())
                }

                args.append(contentsOf: self.files.map(\.string))

                c.arguments = .init(args)

                return c
            }
        }

        public func extract(_ options: ExtractCommand.Option...) -> ExtractCommand {
            ExtractCommand(self, options)
        }

        public struct ExtractCommand {
            var tar: TarCommand

            var options: [Option]

            init(_ tar: TarCommand, _ options: [Option]) {
                self.tar = tar
                self.options = options
            }

            public enum Option {
                case archive(FilePath)
                case compressed
                case verbose

                func args() -> [String] {
                    switch self {
                    case let .archive(archive):
                        return ["--file", "\(archive)"]
                    case .compressed:
                        return ["-z"]
                    case .verbose:
                        return ["-v"]
                    }
                }
            }

            public func config() -> Configuration {
                var c = self.tar.config()

                var args = c.arguments.storage.map(\.description)

                args.append("-x")

                for opt in self.options {
                    args.append(contentsOf: opt.args())
                }

                c.arguments = .init(args)

                return c
            }
        }
    }
}

extension SystemCommand.TarCommand.CreateCommand: Runnable {}
extension SystemCommand.TarCommand.ExtractCommand: Runnable {}
