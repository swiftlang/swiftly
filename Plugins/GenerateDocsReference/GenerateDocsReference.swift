import PackagePlugin

@main
struct GenerateDocsReferencePlugin: CommandPlugin {
    func performCommand(
        context: PluginContext,
        arguments: [String]
    ) async throws {
        // Locate generation tool.
        let generationToolFile = try context.tool(named: "generate-docs-reference").url
        // Create an extractor to extract plugin-only arguments from the `arguments`
        // array.
        var extractor = ArgumentExtractor(arguments)

        // Run generation tool once if help is requested.
        if extractor.helpRequest() {
            try generationToolFile.exec(arguments: ["--help"])
            print(
                """
                ADDITIONAL OPTIONS:
                  --configuration <configuration>
                                          Tool build configuration used to generate the
                                          reference document. (default: release)

                NOTE: The "GenerateDocsReference" plugin handles passing the "<tool>" and
                "--output-directory <output-directory>" arguments. Manually supplying
                these arguments will result in a runtime failure.
                """)
            return
        }

        // Extract configuration argument before making it to the
        // "generate-docs-reference" tool.
        let configuration = try extractor.configuration()

        // Build all products first.
        print("Building package in \(configuration) mode...")
        let buildResult = try packageManager.build(
            .product("swiftly"),
            parameters: .init(configuration: configuration)
        )

        guard buildResult.succeeded else {
            throw GenerateDocsReferencePluginError.buildFailed(buildResult.logText)
        }
        print("Built package in \(configuration) mode")

        // Run generate-docs-reference on all executable artifacts.
        for builtArtifact in buildResult.builtArtifacts {
            // Skip non-executable targets
            guard builtArtifact.kind == .executable else { continue }

            // Get the artifacts name.
            let executableName = builtArtifact.url.lastPathComponent

            print("Generating docs reference for \(executableName)...")

            let outputFile = context.package.directoryURL
                .appendingPathComponent("Documentation")
                .appendingPathComponent("SwiftlyDocs.docc")
                .appendingPathComponent("swiftly-cli-reference.md")

            // Create generation tool arguments.
            var generationToolArguments = [
                builtArtifact.url.path(percentEncoded: false),
                "--output-file",
                outputFile.path(percentEncoded: false),
            ]
            generationToolArguments.append(
                contentsOf: extractor.remainingArguments)

            // Spawn generation tool.
            try generationToolFile.exec(arguments: generationToolArguments)
            print("Generated docs reference in '\(outputFile)'")
        }
    }
}
