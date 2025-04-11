// swift-tools-version:6.0

import PackageDescription

let package = Package(
    name: "swiftly",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(
            name: "swiftly",
            targets: ["Swiftly"]
        ),
        .executable(
            name: "test-swiftly",
            targets: ["TestSwiftly"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/swift-server/async-http-client", from: "1.24.0"),
        .package(url: "https://github.com/swift-server/swift-openapi-async-http-client", from: "1.1.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.80.0"),
        .package(url: "https://github.com/apple/swift-tools-support-core.git", from: "0.7.2"),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-openapi-generator", from: "1.6.0"),
        .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.7.0"),
        // This dependency provides the correct version of the formatter so that you can run `swift run swiftformat Package.swift Plugins/ Sources/ Tests/`
        .package(url: "https://github.com/nicklockwood/SwiftFormat", exact: "0.49.18"),
    ],
    targets: [
        .executableTarget(
            name: "Swiftly",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .target(name: "SwiftlyCore"),
                .target(name: "LinuxPlatform", condition: .when(platforms: [.linux])),
                .target(name: "MacOSPlatform", condition: .when(platforms: [.macOS])),
                .product(name: "SwiftToolsSupport-auto", package: "swift-tools-support-core"),
            ]
        ),
        .executableTarget(
            name: "TestSwiftly",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .target(name: "SwiftlyCore"),
                .target(name: "LinuxPlatform", condition: .when(platforms: [.linux])),
                .target(name: "MacOSPlatform", condition: .when(platforms: [.macOS])),
            ]
        ),
        .target(
            name: "SwiftlyCore",
            dependencies: [
                "SwiftlyDownloadAPI",
                "SwiftlyWebsiteAPI",
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "NIOFoundationCompat", package: "swift-nio"),
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "OpenAPIAsyncHTTPClient", package: "swift-openapi-async-http-client"),
            ],
        ),
        .target(
            name: "SwiftlyDownloadAPI",
            dependencies: [
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
            ],
            plugins: [
                .plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator"),
            ]
        ),
        .target(
            name: "SwiftlyWebsiteAPI",
            dependencies: [
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
            ],
            plugins: [
                .plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator"),
            ]
        ),
        .target(
            name: "SwiftlyDocs",
            path: "Documentation"
        ),
        .plugin(
            name: "GenerateDocsReference",
            capability: .command(
                intent: .custom(
                    verb: "generate-docs-reference",
                    description: "Generate a documentation reference for swiftly."
                ),
                permissions: [
                    .writeToPackageDirectory(reason: "This command generates documentation."),
                ]
            ),
            dependencies: ["generate-docs-reference"]
        ),
        .executableTarget(
            name: "generate-docs-reference",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Tools/generate-docs-reference"
        ),
        .executableTarget(
            name: "build-swiftly-release",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Tools/build-swiftly-release"
        ),
        .target(
            name: "LinuxPlatform",
            dependencies: [
                "SwiftlyCore",
                "CLibArchive",
            ],
            linkerSettings: [
                .linkedLibrary("z"),
            ]
        ),
        .target(
            name: "MacOSPlatform",
            dependencies: [
                "SwiftlyCore",
            ]
        ),
        .systemLibrary(
            name: "CLibArchive",
            pkgConfig: "libarchive",
            providers: [
                .apt(["libarchive-dev"]),
            ]
        ),
        .testTarget(
            name: "SwiftlyTests",
            dependencies: ["Swiftly"],
            resources: [
                .embedInCode("mock-signing-key-private.pgp"),
            ]
        ),
    ]
)
