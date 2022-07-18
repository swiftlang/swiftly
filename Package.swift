// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

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
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .executable(
            name: "swiftly",
            targets: ["Swiftly"]
        ),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.1.2"),
        .package(url: "https://github.com/swift-server/async-http-client", from: "1.9.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.38.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
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
            name: "swiftlyTests",
            dependencies: ["Swiftly"]
        ),
    ]
)
