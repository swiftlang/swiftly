// swift-tools-version:5.7

import PackageDescription

let package = Package(
    name: "swiftly",
    // Current supported Darwin family: macOS
    platforms: [.macOS(.v13)],
    products: [
        .executable(
            name: "swiftly",
            targets: ["Swiftly"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.1.2"),
        .package(url: "https://github.com/swift-server/async-http-client", from: "1.9.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.38.0"),
        .package(url: "https://github.com/apple/swift-tools-support-core.git", from: "0.2.7"),
    ],
    targets: [
        .executableTarget(
            name: "Swiftly",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .target(name: "SwiftlyCore"),
                .target(name: "LinuxPlatform", condition: .when(platforms: [.linux])),
                .target(name: "DarwinPlatform", condition: .when(platforms: [.macOS])),
                .product(name: "SwiftToolsSupport-auto", package: "swift-tools-support-core"),
            ]
        ),
        .target(
            name: "SwiftlyCore",
            dependencies: [
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "NIOFoundationCompat", package: "swift-nio"),
            ]
        ),
        .target(
            name: "DarwinPlatform",
            dependencies: [
                "SwiftlyCore",
                "Archive",
            ],
            linkerSettings: [
                .linkedLibrary("z"),
            ]
        ),
        .target(
            name: "LinuxPlatform",
            dependencies: [
                "SwiftlyCore",
                "Archive",
            ],
            linkerSettings: [
                .linkedLibrary("z"),
            ]
        ),
        .target(
            name: "Archive",
            dependencies: [
                "CLibArchive",
            ]
        ),
        .systemLibrary(
            name: "CLibArchive",
            pkgConfig: "libarchive",
            providers: [
                .apt(["libarchive-dev"]),
                // For pkg-config to find libarchive you may need to set:
                // `export PKG_CONFIG_PATH="/opt/homebrew/opt/libarchive/lib/pkgconfig"`
                .brew(["libarchive"]),
            ]
        ),
        .testTarget(
            name: "SwiftlyTests",
            dependencies: ["Swiftly"]
        ),
    ]
)
