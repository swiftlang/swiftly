import ArgumentParser
import ArgumentParserToolInfo
import Foundation

@main
struct GenerateDocsReference: ParsableCommand {
    enum Error: Swift.Error {
        case failedToRunSubprocess(error: Swift.Error)
        case unableToParseToolOutput(error: Swift.Error)
        case unsupportedDumpHelpVersion(expected: Int, found: Int)
        case failedToGenerateDocsReferencePage(error: Swift.Error)
    }

    static let configuration = CommandConfiguration(
        commandName: "generate-docs-reference",
        abstract: "Generate a docs reference for the provided tool."
    )

    @Argument(help: "Tool to generate docs.")
    var tool: String

    @Option(name: .shortAndLong, help: "File to save generated docs. Use '-' for stdout.")
    var outputFile: String

    func validate() throws {}

    func run() throws {
        let data: Data
        do {
            let tool = URL(fileURLWithPath: tool)
            let output = try executeCommand(
                executable: tool, arguments: ["--experimental-dump-help"]
            )
            data = output.data(using: .utf8) ?? Data()
        } catch {
            throw Error.failedToRunSubprocess(error: error)
        }

        do {
            let toolInfoThin = try JSONDecoder().decode(ToolInfoHeader.self, from: data)
            guard toolInfoThin.serializationVersion == 0 else {
                throw Error.unsupportedDumpHelpVersion(
                    expected: 0,
                    found: toolInfoThin.serializationVersion
                )
            }
        } catch {
            throw Error.unableToParseToolOutput(error: error)
        }

        let toolInfo: ToolInfoV0
        do {
            toolInfo = try JSONDecoder().decode(ToolInfoV0.self, from: data)
        } catch {
            throw Error.unableToParseToolOutput(error: error)
        }

        do {
            if self.outputFile == "-" {
                try self.generatePages(from: toolInfo.command, savingTo: nil)
            } else {
                try self.generatePages(
                    from: toolInfo.command,
                    savingTo: URL(fileURLWithPath: self.outputFile)
                )
            }
        } catch {
            throw Error.failedToGenerateDocsReferencePage(error: error)
        }
    }

    func generatePages(from command: CommandInfoV0, savingTo file: URL?) throws {
        let page = command.toMD([])

        if let file {
            try page.write(to: file, atomically: true, encoding: .utf8)
        } else {
            print(page)
        }
    }
}

extension CommandInfoV0 {
    public func toMD(_ path: [String]) -> String {
        var result = String(repeating: "#", count: path.count + 1) + " \(self.commandName)\n\n"

        if path.count == 0 {
            result +=
                "<!-- THIS FILE HAS BEEN GENERATED using the following command: swift package plugin generate-docs-reference -->\n\n"
        }

        if let abstract = self.abstract {
            result += "\(abstract)\n\n"
        }

        if let args = self.arguments, args.count != 0 {
            result += "```\n"
            result += (path + [self.commandName]).joined(separator: " ") + " " + self.usage()
            result += "\n```\n\n"
        }

        if let discussion = self.discussion {
            result += "\(discussion)\n\n"
        }

        if let args = self.arguments {
            for arg in args {
                guard arg.shouldDisplay else {
                    continue
                }

                result += "**\(arg.identity()):**\n\n"
                if let abstract = arg.abstract {
                    result += "*\(abstract)*\n\n"
                }
                if let discussion = arg.discussion {
                    result += discussion + "\n\n"
                }
                result += "\n"
            }
        }

        for subcommand in self.subcommands ?? [] {
            result += subcommand.toMD(path + [self.commandName]) + "\n\n"
        }

        return result
    }

    public func usage() -> String {
        guard let args = self.arguments else {
            return ""
        }

        return args.map { $0.usage() }.joined(separator: " ")
    }
}

extension ArgumentInfoV0 {
    public func usage() -> String {
        guard self.shouldDisplay else {
            return ""
        }

        let name: String
        if let preferred = self.preferredName {
            name = preferred.name
        } else if let value = self.valueName {
            name = value
        } else {
            return ""
        }

        // TODO: default values, short, etc.

        var inner =
            switch self.kind
        {
        case .positional:
            "<\(name)>"
        case .option:
            "--\(name)=<\(self.valueName ?? "")>"
        case .flag:
            "--\(name)"
        }

        if self.isRepeating {
            inner += "..."
        }

        if self.isOptional {
            return "[\(inner)]"
        }

        return inner
    }

    public func identity() -> String {
        let name: String
        if let preferred = self.preferredName {
            name = preferred.name
        } else if let value = self.valueName {
            name = value
        } else {
            return ""
        }

        // TODO: default values, values, short, etc.

        let inner =
            switch self.kind
        {
        case .positional:
            "\(name)"
        case .option:
            "--\(name)=\\<\(self.valueName ?? "")\\>"
        case .flag:
            "--\(name)"
        }

        return inner
    }
}
