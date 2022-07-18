// swift-tools-version:5.7

import class Foundation.ProcessInfo
import PackageDescription

var linuxSwiftSettings: [SwiftSetting] = []

#if os(Linux)
    enum LinuxDistro: String {
        case ubuntu1804
        case ubuntu2004

        func define() -> String {
            switch self {
            case .ubuntu1804:
                return "UBUNTU_1804"
            case .ubuntu2004:
                return "UBUNTU_2004"
            }
        }
    }

    let linuxDistroEnvVar = "SWIFTLY_LINUX_DISTRIBUTION"

    guard let distroString = ProcessInfo.processInfo.environment[linuxDistroEnvVar] else {
        fatalError("please set \(linuxDistroEnvVar)")
    }

    guard let distro = LinuxDistro(rawValue: distroString) else {
        fatalError("unsupported linux distribution: \(distroString)")
    }

    linuxSwiftSettings.append(.define(distro.define()))
#endif

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
    ],
    targets: [
        .executableTarget(
            name: "Swiftly",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .target(name: "SwiftlyCore"),
                .target(name: "LinuxPlatform", condition: .when(platforms: [.linux])),
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
            ],
            swiftSettings: linuxSwiftSettings
        ),
        .testTarget(
            name: "SwiftlyTests",
            dependencies: ["Swiftly"]
        ),
    ]
)
