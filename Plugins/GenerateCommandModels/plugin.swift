import PackagePlugin

@main
struct MyPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        guard let target = target as? SourceModuleTarget else { return [] }

        let jsonSources = target.sourceFiles.map(\.path).filter { $0.extension == "json" }

        guard jsonSources.count > 0 else { return [] }

        let outputPath = context.pluginWorkDirectory.appending("Commands.swift")

        return [
            .buildCommand(
                displayName: "Generating Command Models from dumped JSON help",
                executable: try context.tool(named: "generate-command-models").path,
                arguments: ["--output-file", outputPath] + jsonSources,
                inputFiles: jsonSources,
                outputFiles: [outputPath]
            ),
        ]
    }
}
