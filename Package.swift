// swift-tools-version:5.10

import Foundation
import PackageDescription

let swiftlyTarget: Target = .executableTarget(
    name: "Swiftly",
    dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .target(name: "SwiftlyCore"),
        .product(name: "SwiftToolsSupport-auto", package: "swift-tools-support-core"),
    ]
)

let ghApiCacheResources = (1...16).map { Resource.embedInCode("gh-api-cache/swift-tags-page\($0).json") }
let ghApiCacheExcludedResources = (17...27).map { "gh-api-cache/swift-tags-page\($0).json" }

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
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/swift-server/async-http-client", from: "1.21.2"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.64.0"),
        .package(url: "https://github.com/apple/swift-tools-support-core.git", from: "0.6.1"),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.3.0"),
        // This dependency provides the correct version of the formatter so that you can run `swift run swiftformat Package.swift Plugins/ Sources/ Tests/`
        .package(url: "https://github.com/nicklockwood/SwiftFormat", exact: "0.49.18"),
    ],
    targets: [
        swiftlyTarget,
        .target(
            name: "SwiftlyCore",
            dependencies: [
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "NIOFoundationCompat", package: "swift-nio"),
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
        .testTarget(
            name: "SwiftlyTests",
            dependencies: ["Swiftly"],
            exclude: ghApiCacheExcludedResources,
            resources: ghApiCacheResources + [
                .embedInCode("mock-signing-key-private.pgp"),
            ]
        ),
    ]
)

#if os(Linux)

package.dependencies.append(.package(path: "libarchive"))
package.targets.append(
    .target(
        name: "LinuxPlatform",
        dependencies: [
            .target(name: "SwiftlyCore"),
            .product(name: "archive-devel", package: "libarchive"),
        ]
    )
)
swiftlyTarget.dependencies.append(.target(name: "LinuxPlatform"))

#elseif os(macOS)

package.targets.append(
    .target(
        name: "MacOSPlatform",
        dependencies: [
            "SwiftlyCore",
        ]
    )
)
swiftlyTarget.dependencies.append(.target(name: "MacOSPlatform"))

#endif
