import Foundation
import SystemPackage

public enum SystemCommand {}

// This file contains a set of system commands that's used by Swiftly and its related tests and tooling

extension SystemCommand {
    // Directory Service command line utility for macOS
    // See dscl(1) for details
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
    // Create or operate on universal files
    // See lipo(1) for details
    public static func lipo(executable: Executable = LipoCommand.defaultExecutable, inputFiles: FilePath...) -> LipoCommand {
        Self.lipo(executable: executable, inputFiles: inputFiles)
    }

    // Create or operate on universal files
    // See lipo(1) for details
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

extension SystemCommand {
    // Build a macOS Installer component package from on-disk files
    // See pkgbuild(1) for more details
    public static func pkgbuild(executable: Executable = PkgbuildCommand.defaultExecutable, _ options: PkgbuildCommand.Option..., root: FilePath, packageOutputPath: FilePath) -> PkgbuildCommand {
        Self.pkgbuild(executable: executable, options: options, root: root, packageOutputPath: packageOutputPath)
    }

    // Build a macOS Installer component package from on-disk files
    // See pkgbuild(1) for more details
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

extension SystemCommand {
    // get entries from Name Service Switch libraries
    // See getent(1) for more details
    public static func getent(executable: Executable = GetentCommand.defaultExecutable, database: String, keys: String...) -> GetentCommand {
        Self.getent(executable: executable, database: database, keys: keys)
    }

    // get entries from Name Service Switch libraries
    // See getent(1) for more details
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
    // the stupid content tracker
    // See git(1) for more information.
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

extension SystemCommand {
    // manipulate tape archives
    // See tar(1) for more details
    public static func tar(executable: Executable = TarCommand.defaultExecutable, _ options: TarCommand.Option...) -> TarCommand {
        Self.tar(executable: executable, options)
    }

    // manipulate tape archives
    // See tar(1) for more details
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

extension SystemCommand {
    public static func swift(executable: Executable = SwiftCommand.defaultExecutable) -> SwiftCommand {
        SwiftCommand(executable: executable)
    }

    public struct SwiftCommand {
        public static var defaultExecutable: Executable { .name("swift") }

        public var executable: Executable

        public init(executable: Executable) {
            self.executable = executable
        }

        func config() -> Configuration {
            var args: [String] = []

            return Configuration(
                executable: self.executable,
                arguments: Arguments(args),
                environment: .inherit
            )
        }

        public func package() -> PackageCommand {
            PackageCommand(self)
        }

        public struct PackageCommand {
            var swift: SwiftCommand

            init(_ swift: SwiftCommand) {
                self.swift = swift
            }

            public func config() -> Configuration {
                var c = self.swift.config()

                var args = c.arguments.storage.map(\.description)

                args.append("package")

                c.arguments = .init(args)

                return c
            }

            public func reset() -> ResetCommand {
                ResetCommand(self)
            }

            public struct ResetCommand {
                var packageCommand: PackageCommand

                init(_ packageCommand: PackageCommand) {
                    self.packageCommand = packageCommand
                }

                public func config() -> Configuration {
                    var c = self.packageCommand.config()

                    var args = c.arguments.storage.map(\.description)

                    args.append("reset")

                    c.arguments = .init(args)

                    return c
                }
            }

            public func clean() -> CleanCommand {
                CleanCommand(self)
            }

            public struct CleanCommand {
                var packageCommand: PackageCommand

                init(_ packageCommand: PackageCommand) {
                    self.packageCommand = packageCommand
                }

                public func config() -> Configuration {
                    var c = self.packageCommand.config()

                    var args = c.arguments.storage.map(\.description)

                    args.append("clean")

                    c.arguments = .init(args)

                    return c
                }
            }

            public func _init(_ options: InitCommand.Option...) -> InitCommand {
                self._init(options: options)
            }

            public func _init(options: [InitCommand.Option]) -> InitCommand {
                InitCommand(self, options)
            }

            public struct InitCommand {
                var packageCommand: PackageCommand

                var options: [Option]

                public enum Option {
                    case type(String)
                    case packagePath(FilePath)

                    func args() -> [String] {
                        switch self {
                        case let .type(type):
                            return ["--type=\(type)"]
                        case let .packagePath(packagePath):
                            return ["--package-path=\(packagePath)"]
                        }
                    }
                }

                init(_ packageCommand: PackageCommand, _ options: [Option]) {
                    self.packageCommand = packageCommand
                    self.options = options
                }

                public func config() -> Configuration {
                    var c = self.packageCommand.config()

                    var args = c.arguments.storage.map(\.description)

                    args.append("init")

                    for opt in self.options {
                        args.append(contentsOf: opt.args())
                    }

                    c.arguments = .init(args)

                    return c
                }
            }
        }

        public func sdk() -> SdkCommand {
            SdkCommand(self)
        }

        public struct SdkCommand {
            var swift: SwiftCommand

            init(_ swift: SwiftCommand) {
                self.swift = swift
            }

            public func config() -> Configuration {
                var c = self.swift.config()

                var args = c.arguments.storage.map(\.description)

                args.append("sdk")

                c.arguments = .init(args)

                return c
            }

            public func install(_ bundlePathOrUrl: String, checksum: String? = nil) -> InstallCommand {
                InstallCommand(self, bundlePathOrUrl, checksum: checksum)
            }

            public struct InstallCommand {
                var sdkCommand: SdkCommand
                var bundlePathOrUrl: String
                var checksum: String?

                init(_ sdkCommand: SdkCommand, _ bundlePathOrUrl: String, checksum: String?) {
                    self.sdkCommand = sdkCommand
                    self.bundlePathOrUrl = bundlePathOrUrl
                    self.checksum = checksum
                }

                public func config() -> Configuration {
                    var c = self.sdkCommand.config()

                    var args = c.arguments.storage.map(\.description)

                    args.append("install")

                    args.append(self.bundlePathOrUrl)

                    if let checksum = self.checksum {
                        args.append("--checksum=\(checksum)")
                    }

                    c.arguments = .init(args)

                    return c
                }
            }

            public func remove(_ sdkIdOrBundleName: String) -> RemoveCommand {
                RemoveCommand(self, sdkIdOrBundleName)
            }

            public struct RemoveCommand {
                var sdkCommand: SdkCommand
                var sdkIdOrBundleName: String

                init(_ sdkCommand: SdkCommand, _ sdkIdOrBundleName: String) {
                    self.sdkCommand = sdkCommand
                    self.sdkIdOrBundleName = sdkIdOrBundleName
                }

                public func config() -> Configuration {
                    var c = self.sdkCommand.config()

                    var args = c.arguments.storage.map(\.description)

                    args.append("remove")

                    args.append(self.sdkIdOrBundleName)

                    c.arguments = .init(args)

                    return c
                }
            }
        }

        public func build(_ options: BuildCommand.Option...) -> BuildCommand {
            BuildCommand(self, options)
        }

        public struct BuildCommand {
            var swift: SwiftCommand
            var options: [Option]

            init(_ swift: SwiftCommand, _ options: [Option]) {
                self.swift = swift
                self.options = options
            }

            public func config() -> Configuration {
                var c = self.swift.config()

                var args = c.arguments.storage.map(\.description)

                args.append("build")

                for opt in self.options {
                    args.append(contentsOf: opt.args())
                }

                c.arguments = .init(args)

                return c
            }

            public enum Option {
                case arch(String)
                case configuration(String)
                case packagePath(FilePath)
                case pkgConfigPath(String)
                case product(String)
                case swiftSdk(String)
                case staticSwiftStdlib

                func args() -> [String] {
                    switch self {
                    case let .arch(arch):
                        return ["--arch=\(arch)"]
                    case let .configuration(configuration):
                        return ["--configuration=\(configuration)"]
                    case let .packagePath(packagePath):
                        return ["--package-path=\(packagePath)"]
                    case let .pkgConfigPath(pkgConfigPath):
                        return ["--pkg-config-path=\(pkgConfigPath)"]
                    case let .swiftSdk(sdk):
                        return ["--swift-sdk=\(sdk)"]
                    case .staticSwiftStdlib:
                        return ["--static-swift-stdlib"]
                    case let .product(product):
                        return ["--product=\(product)"]
                    }
                }
            }
        }
    }
}

extension SystemCommand.SwiftCommand.PackageCommand.ResetCommand: Runnable {}
extension SystemCommand.SwiftCommand.PackageCommand.CleanCommand: Runnable {}
extension SystemCommand.SwiftCommand.PackageCommand.InitCommand: Runnable {}
extension SystemCommand.SwiftCommand.SdkCommand.InstallCommand: Runnable {}
extension SystemCommand.SwiftCommand.SdkCommand.RemoveCommand: Runnable {}
extension SystemCommand.SwiftCommand.BuildCommand: Runnable {}

extension SystemCommand {
    // make utility to maintain groups of programs
    // See make(1) for more information.
    public static func make(executable: Executable = MakeCommand.defaultExecutable) -> MakeCommand {
        MakeCommand(executable: executable)
    }

    public struct MakeCommand {
        public static var defaultExecutable: Executable { .name("make") }

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

        public func install() -> InstallCommand {
            InstallCommand(self)
        }

        public struct InstallCommand {
            var make: MakeCommand

            init(_ make: MakeCommand) {
                self.make = make
            }

            public func config() -> Configuration {
                var c = self.make.config()

                var args = c.arguments.storage.map(\.description)

                args.append("install")

                c.arguments = .init(args)

                return c
            }
        }
    }
}

extension SystemCommand.MakeCommand: Runnable {}
extension SystemCommand.MakeCommand.InstallCommand: Runnable {}

extension SystemCommand {
    // remove symbols
    // See strip(1) for more information.
    public static func strip(executable: Executable = StripCommand.defaultExecutable, names: FilePath...) -> StripCommand {
        self.strip(executable: executable, names: names)
    }

    // remove symbols
    // See strip(1) for more information.
    public static func strip(executable: Executable = StripCommand.defaultExecutable, names: [FilePath]) -> StripCommand {
        StripCommand(executable: executable, names: names)
    }

    public struct StripCommand {
        public static var defaultExecutable: Executable { .name("strip") }

        public var executable: Executable

        public var names: [FilePath]

        public init(executable: Executable, names: [FilePath]) {
            self.executable = executable
            self.names = names
        }

        public func config() -> Configuration {
            var args: [String] = []

            args.append(contentsOf: self.names.map(\.string))

            return Configuration(
                executable: self.executable,
                arguments: Arguments(args),
                environment: .inherit
            )
        }
    }
}

extension SystemCommand.StripCommand: Runnable {}

extension SystemCommand {
    // calculate a message-digest fingerprint (checksum) for a file
    // See sha256sum(1) for more information.
    public static func sha256sum(executable: Executable = Sha256SumCommand.defaultExecutable, files: FilePath...) -> Sha256SumCommand {
        self.sha256sum(executable: executable, files: files)
    }

    // calculate a message-digest fingerprint (checksum) for a file
    // See sha256sum(1) for more information.
    public static func sha256sum(executable: Executable, files: [FilePath]) -> Sha256SumCommand {
        Sha256SumCommand(executable: executable, files: files)
    }

    public struct Sha256SumCommand {
        public static var defaultExecutable: Executable { .name("sha256sum") }

        public var executable: Executable

        public var files: [FilePath]

        public init(executable: Executable, files: [FilePath]) {
            self.executable = executable
            self.files = files
        }

        public func config() -> Configuration {
            var args: [String] = []

            args.append(contentsOf: self.files.map(\.string))

            return Configuration(
                executable: self.executable,
                arguments: Arguments(args),
                environment: .inherit
            )
        }
    }
}

extension SystemCommand.Sha256SumCommand: Output {}

extension SystemCommand {
    // Build a product archive for the macOS Installer or the Mac App Store.
    // See productbuild(1) for more information.
    public static func productbuild(executable: Executable = ProductBuildCommand.defaultExecutable) -> ProductBuildCommand {
        ProductBuildCommand(executable: executable)
    }

    public struct ProductBuildCommand {
        public static var defaultExecutable: Executable { .name("productbuild") }

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

        public func synthesize(package: FilePath, distributionOutputPath: FilePath) -> SynthesizeCommand {
            SynthesizeCommand(self, package: package, distributionOutputPath: distributionOutputPath)
        }

        public struct SynthesizeCommand {
            public var productBuildCommand: ProductBuildCommand

            public var package: FilePath

            public var distributionOutputPath: FilePath

            public init(_ productBuildCommand: ProductBuildCommand, package: FilePath, distributionOutputPath: FilePath) {
                self.productBuildCommand = productBuildCommand
                self.package = package
                self.distributionOutputPath = distributionOutputPath
            }

            public func config() -> Configuration {
                var c = self.productBuildCommand.config()

                var args = c.arguments.storage.map(\.description)

                args.append("--synthesize")

                args.append(contentsOf: ["--package", "\(self.package)"])
                args.append("\(self.distributionOutputPath)")

                c.arguments = .init(args)

                return c
            }
        }

        public func distribution(_ options: DistributionCommand.Option..., distPath: FilePath, productOutputPath: FilePath) -> DistributionCommand {
            self.distribution(options, distPath: distPath, productOutputPath: productOutputPath)
        }

        public func distribution(_ options: [DistributionCommand.Option], distPath: FilePath, productOutputPath: FilePath) -> DistributionCommand {
            DistributionCommand(self, options, distPath: distPath, productOutputPath: productOutputPath)
        }

        public struct DistributionCommand {
            public var productBuildCommand: ProductBuildCommand

            public var options: [Option]

            public var distPath: FilePath

            public var productOutputPath: FilePath

            public enum Option {
                case packagePath(FilePath)
                case sign(String)

                public func args() -> [String] {
                    switch self {
                    case let .packagePath(packagePath):
                        ["--package-path", "\(packagePath)"]
                    case let .sign(sign):
                        ["--sign", "\(sign)"]
                    }
                }
            }

            public init(_ productBuildCommand: ProductBuildCommand, _ options: [Option], distPath: FilePath, productOutputPath: FilePath) {
                self.productBuildCommand = productBuildCommand
                self.options = options
                self.distPath = distPath
                self.productOutputPath = productOutputPath
            }

            public func config() -> Configuration {
                var c = self.productBuildCommand.config()

                var args = c.arguments.storage.map(\.description)

                args.append("--distribution")

                args.append("\(self.distPath)")

                for opt in self.options {
                    args.append(contentsOf: opt.args())
                }

                args.append("\(self.productOutputPath)")

                c.arguments = .init(args)

                return c
            }
        }
    }
}

extension SystemCommand.ProductBuildCommand.SynthesizeCommand: Runnable {}
extension SystemCommand.ProductBuildCommand.DistributionCommand: Runnable {}

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
