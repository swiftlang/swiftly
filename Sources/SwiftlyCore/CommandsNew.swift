import SystemPackage

extension SystemCommand {
    // Directory Service command line utility for macOS. See dscl(1) for more information.
    public static func dscl(executable: Executable = dsclCommand.defaultExecutable, datasource: String? = nil) -> dsclCommand {
        dsclCommand(executable: executable, datasource: datasource)
    }

    public struct dsclCommand {
        public static var defaultExecutable: Executable { .name("dscl") }
        public var executable: Executable
        public var datasource: String?

        public init(executable: Executable, datasource: String? = nil) {
            self.executable = executable
            self.datasource = datasource
        }

        public func config() -> Configuration {
            var args: [String] = []

            if let datasource = self.datasource { args += [datasource.description] }

            return Configuration(
                executable: self.executable,
                arguments: Arguments(args),
                environment: .inherit
            )
        }

        public func read(path: FilePath? = nil, key: [String]?) -> readCommand {
            readCommand(parent: self, path: path, key: key)
        }

        public struct readCommand {
            public var parent: dsclCommand
            public var path: FilePath?
            public var key: [String]?

            public init(parent: dsclCommand, path: FilePath? = nil, key: [String]?) {
                self.parent = parent
                self.path = path
                self.key = key
            }

            public func config() -> Configuration {
                var c = self.parent.config()

                var args = c.arguments.storage.map(\.description)

                args.append("-read")

                if let path = self.path { args += [path.description] }
                if let key = self.key { args += key.map(\.description) }

                c.arguments = .init(args)

                return c
            }
        }
    }
}

extension SystemCommand {
    // get entries from Name Service Switch libraries. See getent(1) for more information.
    public static func getent(executable: Executable = getentCommand.defaultExecutable, database: String, key: String...) -> getentCommand {
        Self.getent(executable: executable, database: database, key: key)
    }

    // get entries from Name Service Switch libraries. See getent(1) for more information.
    public static func getent(executable: Executable = getentCommand.defaultExecutable, database: String, key: [String]) -> getentCommand {
        getentCommand(executable: executable, database: database, key: key)
    }

    public struct getentCommand {
        public static var defaultExecutable: Executable { .name("getent") }
        public var executable: Executable
        public var database: String
        public var key: [String]

        public init(executable: Executable, database: String, key: [String]) {
            self.executable = executable
            self.database = database
            self.key = key
        }

        public func config() -> Configuration {
            var args: [String] = []

            args += [self.database.description]
            args += self.key.map(\.description)

            return Configuration(
                executable: self.executable,
                arguments: Arguments(args),
                environment: .inherit
            )
        }
    }
}

extension SystemCommand {
    // the stupid content tracker. See git(1) for more information.
    public static func git(executable: Executable = gitCommand.defaultExecutable, _ options: gitCommand.Option...) -> gitCommand {
        Self.git(executable: executable, options)
    }

    // the stupid content tracker. See git(1) for more information.
    public static func git(executable: Executable = gitCommand.defaultExecutable, _ options: [gitCommand.Option]) -> gitCommand {
        gitCommand(executable: executable, options)
    }

    public struct gitCommand {
        public static var defaultExecutable: Executable { .name("git") }
        public var executable: Executable
        public var options: [Option]

        public enum Option {
            case workingDir(FilePath)

            public func args() -> [String] {
                switch self {
                case let .workingDir(workingDir):
                    ["-C", String(describing: workingDir)]
                }
            }
        }

        public init(executable: Executable, _ options: [gitCommand.Option]) {
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

        public func _init() -> initCommand {
            initCommand(parent: self)
        }

        public struct initCommand {
            public var parent: gitCommand

            public init(parent: gitCommand) {
                self.parent = parent
            }

            public func config() -> Configuration {
                var c = self.parent.config()

                var args = c.arguments.storage.map(\.description)

                args.append("init")

                c.arguments = .init(args)

                return c
            }
        }

        public func commit(_ options: commitCommand.Option...) -> commitCommand {
            self.commit(options)
        }

        public func commit(_ options: [commitCommand.Option]) -> commitCommand {
            commitCommand(parent: self, options)
        }

        public struct commitCommand {
            public var parent: gitCommand
            public var options: [Option]

            public enum Option {
                case allow_empty
                case allow_empty_message
                case message(String)

                public func args() -> [String] {
                    switch self {
                    case .allow_empty:
                        ["--allow-empty"]
                    case .allow_empty_message:
                        ["--allow-empty-message"]
                    case let .message(message):
                        ["--message", String(describing: message)]
                    }
                }
            }

            public init(parent: gitCommand, _ options: [commitCommand.Option]) {
                self.parent = parent
                self.options = options
            }

            public func config() -> Configuration {
                var c = self.parent.config()

                var args = c.arguments.storage.map(\.description)

                args.append("commit")

                for opt in self.options {
                    args.append(contentsOf: opt.args())
                }

                c.arguments = .init(args)

                return c
            }
        }

        public func log(_ options: logCommand.Option...) -> logCommand {
            self.log(options)
        }

        public func log(_ options: [logCommand.Option]) -> logCommand {
            logCommand(parent: self, options)
        }

        public struct logCommand {
            public var parent: gitCommand
            public var options: [Option]

            public enum Option {
                case max_count(String)
                case pretty(String)

                public func args() -> [String] {
                    switch self {
                    case let .max_count(max_count):
                        ["--max-count", String(describing: max_count)]
                    case let .pretty(pretty):
                        ["--pretty", String(describing: pretty)]
                    }
                }
            }

            public init(parent: gitCommand, _ options: [logCommand.Option]) {
                self.parent = parent
                self.options = options
            }

            public func config() -> Configuration {
                var c = self.parent.config()

                var args = c.arguments.storage.map(\.description)

                args.append("log")

                for opt in self.options {
                    args.append(contentsOf: opt.args())
                }

                c.arguments = .init(args)

                return c
            }
        }

        public func diffindex(_ options: diffindexCommand.Option..., tree_ish: String) -> diffindexCommand {
            self.diffindex(options, tree_ish: tree_ish)
        }

        public func diffindex(_ options: [diffindexCommand.Option], tree_ish: String) -> diffindexCommand {
            diffindexCommand(parent: self, options, tree_ish: tree_ish)
        }

        public struct diffindexCommand {
            public var parent: gitCommand
            public var options: [Option]
            public var tree_ish: String

            public enum Option {
                case quiet

                public func args() -> [String] {
                    switch self {
                    case .quiet:
                        ["--quiet"]
                    }
                }
            }

            public init(parent: gitCommand, _ options: [diffindexCommand.Option], tree_ish: String) {
                self.parent = parent
                self.options = options
                self.tree_ish = tree_ish
            }

            public func config() -> Configuration {
                var c = self.parent.config()

                var args = c.arguments.storage.map(\.description)

                args.append("diff-index")

                for opt in self.options {
                    args.append(contentsOf: opt.args())
                }
                args += [self.tree_ish.description]

                c.arguments = .init(args)

                return c
            }
        }
    }
}

extension SystemCommand {
    // Create or operate on universal files. See lipo(1) for more information.
    public static func lipo(executable: Executable = lipoCommand.defaultExecutable, input_file: FilePath...) -> lipoCommand {
        Self.lipo(executable: executable, input_file: input_file)
    }

    // Create or operate on universal files. See lipo(1) for more information.
    public static func lipo(executable: Executable = lipoCommand.defaultExecutable, input_file: [FilePath]) -> lipoCommand {
        lipoCommand(executable: executable, input_file: input_file)
    }

    public struct lipoCommand {
        public static var defaultExecutable: Executable { .name("lipo") }
        public var executable: Executable
        public var input_file: [FilePath]

        public init(executable: Executable, input_file: [FilePath]) {
            self.executable = executable
            self.input_file = input_file
        }

        public func config() -> Configuration {
            var args: [String] = []

            args += self.input_file.map(\.description)

            return Configuration(
                executable: self.executable,
                arguments: Arguments(args),
                environment: .inherit
            )
        }

        public func create(_ options: createCommand.Option...) -> createCommand {
            self.create(options)
        }

        public func create(_ options: [createCommand.Option]) -> createCommand {
            createCommand(parent: self, options)
        }

        public struct createCommand {
            public var parent: lipoCommand
            public var options: [Option]

            public enum Option {
                case output(FilePath)

                public func args() -> [String] {
                    switch self {
                    case let .output(output):
                        ["-output", String(describing: output)]
                    }
                }
            }

            public init(parent: lipoCommand, _ options: [createCommand.Option]) {
                self.parent = parent
                self.options = options
            }

            public func config() -> Configuration {
                var c = self.parent.config()

                var args = c.arguments.storage.map(\.description)

                args.append("-create")

                for opt in self.options {
                    args.append(contentsOf: opt.args())
                }

                c.arguments = .init(args)

                return c
            }
        }
    }
}

extension SystemCommand {
    // Build a macOS Installer component package from on-disk files. See pkgbuild(1) for more information.
    public static func pkgbuild(executable: Executable = pkgbuildCommand.defaultExecutable, _ options: pkgbuildCommand.Option..., package_output_path: FilePath) -> pkgbuildCommand {
        Self.pkgbuild(executable: executable, options, package_output_path: package_output_path)
    }

    // Build a macOS Installer component package from on-disk files. See pkgbuild(1) for more information.
    public static func pkgbuild(executable: Executable = pkgbuildCommand.defaultExecutable, _ options: [pkgbuildCommand.Option], package_output_path: FilePath) -> pkgbuildCommand {
        pkgbuildCommand(executable: executable, options, package_output_path: package_output_path)
    }

    public struct pkgbuildCommand {
        public static var defaultExecutable: Executable { .name("pkgbuild") }
        public var executable: Executable
        public var options: [Option]
        public var package_output_path: FilePath

        public enum Option {
            case sign(String)
            case identifier(String)
            case version(String)
            case install_location(FilePath)
            case root(FilePath)

            public func args() -> [String] {
                switch self {
                case let .sign(sign):
                    ["--sign", String(describing: sign)]
                case let .identifier(identifier):
                    ["--identifier", String(describing: identifier)]
                case let .version(version):
                    ["--version", String(describing: version)]
                case let .install_location(install_location):
                    ["--install-location", String(describing: install_location)]
                case let .root(root):
                    ["--root", String(describing: root)]
                }
            }
        }

        public init(executable: Executable, _ options: [pkgbuildCommand.Option], package_output_path: FilePath) {
            self.executable = executable
            self.options = options
            self.package_output_path = package_output_path
        }

        public func config() -> Configuration {
            var args: [String] = []

            for opt in self.options {
                args.append(contentsOf: opt.args())
            }
            args += [self.package_output_path.description]

            return Configuration(
                executable: self.executable,
                arguments: Arguments(args),
                environment: .inherit
            )
        }
    }
}

extension SystemCommand {
    // calculate a message-digest fingerprint (checksum) for a file. See sha256sum(1) for more information.
    public static func sha256sum(executable: Executable = sha256sumCommand.defaultExecutable, _ options: sha256sumCommand.Option..., files: FilePath...) -> sha256sumCommand {
        Self.sha256sum(executable: executable, options, files: files)
    }

    // calculate a message-digest fingerprint (checksum) for a file. See sha256sum(1) for more information.
    public static func sha256sum(executable: Executable = sha256sumCommand.defaultExecutable, _ options: [sha256sumCommand.Option], files: [FilePath]) -> sha256sumCommand {
        sha256sumCommand(executable: executable, options, files: files)
    }

    public struct sha256sumCommand {
        public static var defaultExecutable: Executable { .name("sha256sum") }
        public var executable: Executable
        public var options: [Option]
        public var files: [FilePath]

        public enum Option {
            case verbose

            public func args() -> [String] {
                switch self {
                case .verbose:
                    ["--verbose"]
                }
            }
        }

        public init(executable: Executable, _ options: [sha256sumCommand.Option], files: [FilePath]) {
            self.executable = executable
            self.options = options
            self.files = files
        }

        public func config() -> Configuration {
            var args: [String] = []

            for opt in self.options {
                args.append(contentsOf: opt.args())
            }
            args += self.files.map(\.description)

            return Configuration(
                executable: self.executable,
                arguments: Arguments(args),
                environment: .inherit
            )
        }
    }
}

extension SystemCommand {
    // manipulate tape archives. See tar(1) for more information.
    public static func tar(executable: Executable = tarCommand.defaultExecutable, _ options: tarCommand.Option...) -> tarCommand {
        Self.tar(executable: executable, options)
    }

    // manipulate tape archives. See tar(1) for more information.
    public static func tar(executable: Executable = tarCommand.defaultExecutable, _ options: [tarCommand.Option]) -> tarCommand {
        tarCommand(executable: executable, options)
    }

    public struct tarCommand {
        public static var defaultExecutable: Executable { .name("tar") }
        public var executable: Executable
        public var options: [Option]

        public enum Option {
            case directory(FilePath)

            public func args() -> [String] {
                switch self {
                case let .directory(directory):
                    ["-C", String(describing: directory)]
                }
            }
        }

        public init(executable: Executable, _ options: [tarCommand.Option]) {
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

        public func create(_ options: createCommand.Option..., files: [FilePath]?) -> createCommand {
            self.create(options, files: files)
        }

        public func create(_ options: [createCommand.Option], files: [FilePath]?) -> createCommand {
            createCommand(parent: self, options, files: files)
        }

        public struct createCommand {
            public var parent: tarCommand
            public var options: [Option]
            public var files: [FilePath]?

            public enum Option {
                case archive(FilePath)
                case compressed
                case verbose

                public func args() -> [String] {
                    switch self {
                    case let .archive(archive):
                        ["--file", String(describing: archive)]
                    case .compressed:
                        ["-z"]
                    case .verbose:
                        ["-v"]
                    }
                }
            }

            public init(parent: tarCommand, _ options: [createCommand.Option], files: [FilePath]?) {
                self.parent = parent
                self.options = options
                self.files = files
            }

            public func config() -> Configuration {
                var c = self.parent.config()

                var args = c.arguments.storage.map(\.description)

                args.append("--create")

                for opt in self.options {
                    args.append(contentsOf: opt.args())
                }
                if let files = self.files { args += files.map(\.description) }

                c.arguments = .init(args)

                return c
            }
        }

        public func extract(_ options: extractCommand.Option...) -> extractCommand {
            self.extract(options)
        }

        public func extract(_ options: [extractCommand.Option]) -> extractCommand {
            extractCommand(parent: self, options)
        }

        public struct extractCommand {
            public var parent: tarCommand
            public var options: [Option]

            public enum Option {
                case archive(FilePath)
                case compressed
                case verbose

                public func args() -> [String] {
                    switch self {
                    case let .archive(archive):
                        ["--file", String(describing: archive)]
                    case .compressed:
                        ["-z"]
                    case .verbose:
                        ["-v"]
                    }
                }
            }

            public init(parent: tarCommand, _ options: [extractCommand.Option]) {
                self.parent = parent
                self.options = options
            }

            public func config() -> Configuration {
                var c = self.parent.config()

                var args = c.arguments.storage.map(\.description)

                args.append("--extract")

                for opt in self.options {
                    args.append(contentsOf: opt.args())
                }

                c.arguments = .init(args)

                return c
            }
        }
    }
}
