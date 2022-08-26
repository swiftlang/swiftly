// swift-tools-version:5.7

import PackageDescription

let package = Package(
    name: "swiftly",
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
        .package(url: "https://github.com/tsolomko/SWCompression.git", from: "4.7.0"),
        .package(url: "https://github.com/1024jp/GzipSwift", from: "5.2.0"),
    ],
    targets: [
        .executableTarget(
            name: "Swiftly",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .target(name: "SwiftlyCore"),
                .target(name: "LinuxPlatform", condition: .when(platforms: [.linux])),
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
            name: "LinuxPlatform",
            dependencies: [
                "SwiftlyCore",
                "SWCompression",
                .product(name: "Gzip", package: "GzipSwift"),
            ]
        ),
        .testTarget(
            name: "SwiftlyTests",
            dependencies: ["Swiftly"]
        ),
    ]
)
