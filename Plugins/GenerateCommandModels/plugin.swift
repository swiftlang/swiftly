import PackagePlugin

@main
struct GenerateCommandModelsPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        guard let target = target as? SourceModuleTarget else { return [] }

        let jsonSources = target.sourceFiles.map(\.url).filter { $0.pathExtension == "json" }

        guard !jsonSources.isEmpty else { return [] }

        let outputURL = context.pluginWorkDirectoryURL.appendingPathComponent("Commands.swift")

        return [
            .buildCommand(
                displayName: "Generating Command Models from dumped JSON help",
                executable: try context.tool(named: "generate-command-models").url,
                arguments: [
                    "--output-file", outputURL.path,
                ] + jsonSources.map(\.path),
                inputFiles: jsonSources,
                outputFiles: [outputURL]
            ),
        ]
    }
}
