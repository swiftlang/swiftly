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
                case pkgConfigPath(FilePath)
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

extension SystemCommand.sha256sumCommand: Output {}

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
