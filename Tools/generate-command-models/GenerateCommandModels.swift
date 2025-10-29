import ArgumentParser
import ArgumentParserToolInfo
import Foundation
import SystemPackage

struct CommandExtensions: Codable {
    var arguments: [ArgumentExtension]?
}

struct ArgumentExtension: Codable {
    var path: String
    var type: String
}

extension ArgumentInfoV0 {
    var asSwiftName: String {
        self.valueName!.replacingOccurrences(of: "-", with: "_")
    }
}

@main
struct GenerateCommandModels: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "generate-command-models",
        abstract: "Generate models for commands based on a JSON representation of them based on the swift-argument-parser `--experimental-dump-help`."
    )

    @Option var outputFile: String

    @Argument var cmdHelpFiles: [String]

    func validate() throws {}

    func run() async throws {
        let cmdHelpFiles = self.cmdHelpFiles.filter { $0.hasSuffix(".json") && !$0.hasSuffix("-ext.json") }.sorted()

        var allCmds = """
        import SystemPackage


        """

        for cmdHelp in cmdHelpFiles {
            guard !cmdHelp.hasSuffix("-ext.json") else { continue }

            let data = try Data(contentsOf: URL(fileURLWithPath: cmdHelp))
            let toolInfoThin = try JSONDecoder().decode(ToolInfoHeader.self, from: data)
            guard toolInfoThin.serializationVersion == 0 else {
                fatalError("Unsupported serialization version in \(cmdHelp)")
            }

            let toolInfo = try JSONDecoder().decode(ToolInfoV0.self, from: data)

            let cmdExtData = try? Data(contentsOf: URL(fileURLWithPath: cmdHelp.replacingOccurrences(of: ".json", with: "-ext.json")))

            let cmdExt = if let cmdExtData {
                try JSONDecoder().decode(CommandExtensions.self, from: cmdExtData)
            } else {
                CommandExtensions()
            }

            let top = toolInfo.command

            allCmds += """
            extension SystemCommand {
                \(self.asCommand(top, cmdExt).split(separator: "\n", omittingEmptySubsequences: false).map { String($0) }.joined(separator: "\n    "))
            }


            """
        }

        try allCmds.write(to: URL(fileURLWithPath: self.outputFile), atomically: true, encoding: .utf8)
    }

    struct Vars {
        var argInfos: [ArgumentInfoV0]
        var cmdExt: CommandExtensions
        var path: [String]

        init(_ args: [ArgumentInfoV0], _ cmdExt: CommandExtensions, path: [String]) {
            self.argInfos = args.filter { $0.kind == .positional }
            self.cmdExt = cmdExt
            self.path = path
        }

        var haveRepeats: Bool { self.argInfos.filter { $0.isRepeating && !$0.isOptional }.count > 0 }

        func type(_ arg: ArgumentInfoV0) -> String {
            let argPath = (self.path + [arg.valueName!]).joined(separator: ".")
            let ext: ArgumentExtension? = self.cmdExt.arguments?.filter { $0.path == argPath }.first

            if let ext, ext.type == "file" {
                return "FilePath"
            }

            return "String"
        }

        var asSignature: [String] {
            self.argInfos.map {
                $0.isOptional ?
                    "\($0.asSwiftName): \($0.isRepeating ? "[\(self.type($0))]?" : self.type($0) + "? = nil")" :
                    "\($0.asSwiftName): \($0.isRepeating ? "[\(self.type($0))]" : self.type($0))"
            }
        }

        var asSignatureVariadic: [String] {
            self.argInfos.map {
                $0.isOptional ?
                    "\($0.asSwiftName): \($0.isRepeating ? "[\(self.type($0))]?" : self.type($0) + "? = nil")" : // Cannot be both optional and variadic
                    "\($0.asSwiftName): \($0.isRepeating ? "\(self.type($0))..." : self.type($0))"
            }
        }

        var asParameters: [String] {
            self.argInfos.map { $0.asSwiftName + ": " + $0.asSwiftName }
        }

        var asDeclarations: [String] {
            self.argInfos.map { "public var \($0.asSwiftName): \($0.isRepeating ? "[\(self.type($0))]" : self.type($0))\($0.isOptional ? "?" : "")" }
        }

        var asInitializations: [String] {
            self.argInfos.map { "self.\($0.asSwiftName) = \($0.asSwiftName)" }
        }

        var asArgs: [String] {
            self.argInfos.map {
                $0.isOptional ?
                    $0.isRepeating ?
                    "if let \($0.asSwiftName) = self.\($0.asSwiftName) { genArgs += \($0.asSwiftName).map(\\.description)  }" :
                    "if let \($0.asSwiftName) = self.\($0.asSwiftName) { genArgs += [\($0.asSwiftName).description] }" :
                    $0.isRepeating ?
                    "genArgs += self.\($0.asSwiftName).map(\\.description)" :
                    "genArgs += [self.\($0.asSwiftName).description]"
            }
        }
    }

    struct Options {
        var argInfos: [ArgumentInfoV0]
        var cmdExt: CommandExtensions
        var path: [String]

        init(_ args: [ArgumentInfoV0], _ cmdExt: CommandExtensions, path: [String]) {
            self.argInfos = args.filter { $0.kind == .option || $0.kind == .flag }
            self.cmdExt = cmdExt
            self.path = path
        }

        var exist: Bool { self.argInfos.count != 0 }

        func type(_ arg: ArgumentInfoV0) -> String {
            let argPath = (self.path + [arg.valueName!]).joined(separator: ".")
            let ext: ArgumentExtension? = self.cmdExt.arguments?.filter { $0.path == argPath }.first

            if let ext, ext.type == "file" {
                return "FilePath"
            }

            return "String"
        }

        func asSignature(_ structName: String) -> [String] {
            self.exist ? ["_ options: [\(structName).Option]"] : []
        }

        func asSignatureVariadic(_ structName: String) -> [String] {
            self.exist ? ["_ options: \(structName).Option..."] : []
        }

        var asParameter: [String] {
            self.exist ? ["options"] : []
        }

        private func argSwitchCase(_ arg: ArgumentInfoV0) -> String {
            let flag = arg.kind == .flag
            let name: String? = arg.names?.compactMap { name in
                switch name.kind {
                case .long: return "--" + name.name
                case .short, .longWithSingleDash: return "-" + name.name
                }
            }.first

            guard let name else { fatalError("Unable to find a suitable argument name for \(arg)") }

            return """
            case .\(arg.asSwiftName)\(!flag ? "(let \(arg.asSwiftName))" : ""):
                ["\(name)"\(!flag ? ", String(describing: \(arg.asSwiftName))" : "")]
            """.split(separator: "\n", omittingEmptySubsequences: false).joined(separator: "\n        ")
        }

        var asEnum: [String] {
            guard self.exist else { return [] }

            return """
            public enum Option {
                \(self.argInfos.map { "case \($0.asSwiftName)\($0.kind != .flag ? "(\(type($0)))" : "")" }.joined(separator: "\n    "))

                public func args() -> [String] {
                    switch self {
                    \(self.argInfos.map { self.argSwitchCase($0) }.joined(separator: "\n        "))
                    }
                }
            }
            """.split(separator: "\n", omittingEmptySubsequences: false).map { String($0) }
        }

        var asArgs: [String] {
            guard self.exist else { return [] }

            return """
            for opt in self.options {
                genArgs.append(contentsOf: opt.args())
            }
            """.split(separator: "\n", omittingEmptySubsequences: false).map { String($0) }
        }

        var asDeclaration: [String] {
            guard self.argInfos.count != 0 else { return [] }

            return ["public var options: [Option]"]
        }

        var asInitialization: [String] {
            self.exist ? ["self.options = options"] : []
        }
    }

    func asCommand(_ command: CommandInfoV0, _ cmdExt: CommandExtensions, path: [String] = []) -> String {
        let execName = command.commandName

        let swiftName = command.commandName.replacingOccurrences(of: "-", with: "")

        var funcName = swiftName
        if ["init", "import"].contains(funcName) {
            // TODO: handle all of Swift's keywords here
            funcName = "_" + funcName
        }
        let structName = "\(swiftName)Command"

        func indent(_ level: Int) -> String { String(repeating: " ", count: level * 4) }

        let options = Options(command.arguments ?? [], cmdExt, path: path)
        let vars = Vars(command.arguments ?? [], cmdExt, path: path)

        let helperFunc: String
        if path.count == 0 {
            helperFunc = """
            \((options.exist || vars.haveRepeats) ? """
            \(command.abstract != nil ? "// \(command.abstract!.replacingOccurrences(of: "\n", with: ""))" : "")
            public static func \(funcName)(\((["executable: Executable = \(structName).defaultExecutable"] + options.asSignatureVariadic(structName) + vars.asSignatureVariadic).joined(separator: ", "))) -> \(structName) {
                Self.\(funcName)(\((["executable: executable"] + options.asParameter + vars.asParameters).joined(separator: ", ")))
            }
            """ : "")

            \(command.abstract != nil ? "// \(command.abstract!.replacingOccurrences(of: "\n", with: ""))" : "")
            public static func \(funcName)(\((["executable: Executable = \(structName).defaultExecutable"] + options.asSignature(structName) + vars.asSignature).joined(separator: ", "))) -> \(structName) {
                \(structName)(\((["executable: executable"] + options.asParameter + vars.asParameters).joined(separator: ", ")))
            }
            """
        } else {
            helperFunc = """
            \((options.exist || vars.haveRepeats) ? """
            \(command.abstract != nil ? "// \(command.abstract!.replacingOccurrences(of: "\n", with: ""))" : "")
            public func \(funcName)(\((options.asSignatureVariadic(structName) + vars.asSignatureVariadic).joined(separator: ", "))) -> \(structName) {
                self.\(funcName)(\((options.asParameter + vars.asParameters).joined(separator: ", ")))
            }
            """ : "")

            \(command.abstract != nil ? "// \(command.abstract!.replacingOccurrences(of: "\n", with: ""))" : "")
            public func \(funcName)(\((options.asSignature(structName) + vars.asSignature).joined(separator: ", "))) -> \(structName) {
                \(structName)(\((["parent: self"] + options.asParameter + vars.asParameters).joined(separator: ", ")))
            }
            """
        }

        let configFunc: String
        if path.count == 0 {
            let genArgs = options.asArgs + vars.asArgs
            configFunc = """
            public func config() -> Configuration {
                \(genArgs.isEmpty ? "let" : "var") genArgs: [String] = []

                \(genArgs.joined(separator: "\n" + indent(1)))

                return Configuration(
                    executable: self.executable,
                    arguments: Arguments(genArgs),
                    environment: .inherit
                )
            }
            """.split(separator: "\n", omittingEmptySubsequences: false).joined(separator: "\n" + indent(1))
        } else {
            configFunc = """
            public func config() -> Configuration {
                var c = self.parent.config()

                var genArgs = c.arguments.storage.map(\\.description)

                genArgs.append("\(execName)")

                \((options.asArgs + vars.asArgs).joined(separator: "\n" + indent(1)))

                c.arguments = .init(genArgs)

                return c
            }
            """.split(separator: "\n", omittingEmptySubsequences: false).joined(separator: "\n" + indent(1))
        }

        let subcommands = (command.subcommands ?? []).map { asCommand($0, cmdExt, path: path + [$0.commandName]) }.joined(separator: "\n")

        let prefix = indent(path.count)

        return prefix + """
        \(helperFunc)

        public struct \(structName) {
        \(
            (
                (path.count == 0 ? [
                    "public static var defaultExecutable: Executable { .name(\"\(execName)\") }",
                    "public var executable: Executable"
                ] :
                    [
                        "public var parent: \(command.superCommands!.last!)Command",
                    ]) +
                    options.asDeclaration +
                    vars.asDeclarations
            ).joined(separator: "\n" + indent(2))
        )

            \(options.asEnum.joined(separator: "\n" + indent(1)))

            public init(\(([path.count == 0 ? "executable: Executable" : "parent: \(command.superCommands!.last!)Command"] + options.asSignature(structName) + vars.asSignature).joined(separator: ", "))) {
                \(([path.count == 0 ? "self.executable = executable" : "self.parent = parent"] + options.asInitialization + vars.asInitializations).joined(separator: "\n" + indent(2)))
            }

            \(configFunc)

            \(subcommands)
        }
        """.split(separator: "\n", omittingEmptySubsequences: false).joined(separator: "\n" + indent(path.count))
    }
}
