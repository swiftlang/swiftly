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
