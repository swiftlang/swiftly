// swift-tools-version:5.7

import PackageDescription

let swiftlyTarget: Target = .executableTarget(
    name: "Swiftly",
    dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .target(name: "SwiftlyCore"),
        .product(name: "SwiftToolsSupport-auto", package: "swift-tools-support-core")
    ]
)

let package = Package(
    name: "swiftly",
    platforms: [.macOS(.v13)],
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
        .testTarget(
            name: "SwiftlyTests",
            dependencies: ["Swiftly"]
        ),
    ]
)

#if os(Linux)
package.targets.append(
    .target(
        name: "LinuxPlatform",
        dependencies: [
            "SwiftlyCore",
            "CLibArchive",
        ],
        linkerSettings: [
            .linkedLibrary("z"),
        ]
    )
)
package.targets.append(
    .target(
        name: "CLibArchive",
        path: "libarchive/libarchive",
        exclude: ["test"],
        cSettings: [
            .define("HAVE_CONFIG_H", to: "1")
        ]
    )
)
swiftlyTarget.dependencies.append(.target(name: "LinuxPlatform"))
#endif
