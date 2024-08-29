// swift-tools-version:5.10

import Foundation
import PackageDescription

var libTarget: Target = .target(
    name: "CArchive",
    dependencies: [],
    path: "libarchive",
    exclude: ["test"],
    publicHeadersPath: ".",
    cSettings: [
        .define("PLATFORM_CONFIG_H", to: "\"config_swiftpm.h\""),
        .define("HAVE_LIBZ", to: "1"), // zlib comes automatically on macOS through the SDK
    ]
)

#if os(Linux)
let gnuSource: [CSetting] = [.define("_GNU_SOURCE")]
#else
let gnuSource: [CSetting] = []
#endif

let package = Package(
    name: "libarchive",
    products: [
        .library(
            name: "archive-devel",
            type: .static,
            targets: ["CArchive"]
        ),
        .library(
            name: "archive",
            type: .dynamic,
            targets: ["CArchive"]
        ),
        .executable(
            name: "bsdcat",
            targets: ["bsdcat"]
        ),
        /* .executable(
                name: "bsdcpio",
                targets: ["bsdcpio"]
            ), */
        .executable(
            name: "bsdtar",
            targets: ["bsdtar"]
        ),
        .executable(
            name: "bsdunzip",
            targets: ["bsdunzip"]
        ),
    ],
    targets: [
        libTarget,
        .target(
            name: "CArchiveFE",
            dependencies: ["CArchive"],
            path: "libarchive_fe",
            publicHeadersPath: ".",
            cSettings: [.define("PLATFORM_CONFIG_H", to: "\"config_swiftpm.h\"")]
        ),
        .executableTarget(
            name: "bsdcat",
            dependencies: ["CArchive", "CArchiveFE"],
            path: "cat",
            exclude: ["test"],
            cSettings: [.define("PLATFORM_CONFIG_H", to: "\"config_swiftpm.h\"")]
        ),
        /* .executableTarget(
                name: "bsdcpio",
                dependencies: ["CArchive", "CArchiveFE"],
                path: "cpio",
                exclude: ["test"],
                cSettings: [.define("PLATFORM_CONFIG_H", to: "\"config_swiftpm.h\"")]
            ), */
        .executableTarget(
            name: "bsdtar",
            dependencies: ["CArchive", "CArchiveFE"],
            path: "tar",
            exclude: ["test"],
            cSettings: [.define("PLATFORM_CONFIG_H", to: "\"config_swiftpm.h\"")]
        ),
        .executableTarget(
            name: "bsdunzip",
            dependencies: ["CArchive", "CArchiveFE"],
            path: "unzip",
            exclude: ["test"],
            cSettings: gnuSource + [.define("PLATFORM_CONFIG_H", to: "\"config_swiftpm.h\"")]
        ),
    ]
)

// This is a list of system libraries that can be enabled in libarchive to add extra functionality using the specified environment variable in swift build
let libs = [
    // (envVar: "LIBARCHIVE_ENABLE_Z", define: "HAVE_LIBZ", libName: "zlib", moduleLoc: "swiftpm/zlib", pkgConfig: "zlib", aptProvider: "zlib1g-dev")
    (envVar: "LIBARCHIVE_ENABLE_LIBLZMA", define: "HAVE_LIBLZMA", libName: "lzma", moduleLoc: "swiftpm/lzma", pkgConfig: "liblzma", aptProvider: "liblzma-dev"),
    (envVar: "LIBARCHIVE_ENABLE_LIBZSTD", define: "HAVE_LIBZSTD", libName: "zstd", moduleLoc: "swiftpm/zstd", pkgConfig: "libzstd", aptProvider: "libzstd-dev"),
    (envVar: "LIBARCHIVE_ENABLE_LIBACL", define: "HAVE_LIBACL", libName: "acl", moduleLoc: "swiftpm/acl", pkgConfig: "libacl", aptProvider: "libacl1-dev"),
    (envVar: "LIBARCHIVE_ENABLE_LIBATTR", define: "HAVE_LIBATTR", libName: "attr", moduleLoc: "swiftpm/attr", pkgConfig: "libattr", aptProvider: "libattr1-dev"),
    (envVar: "LIBARCHIVE_ENABLE_LIBBSDXML", define: "HAVE_LIBBSDXML", libName: "bsdxml", moduleLoc: "swiftpm/bsdxml", pkgConfig: "libbsdxml", aptProvider: "libbsdxml-dev"),
    (envVar: "LIBARCHIVE_ENABLE_LIBBZ2", define: "HAVE_LIBBZ2", libName: "bz2", moduleLoc: "swiftpm/bz2", pkgConfig: "libbz2", aptProvider: "libbz2-dev"),
    (envVar: "LIBARCHIVE_ENABLE_LIBB2", define: "HAVE_LIBB2", libName: "b2", moduleLoc: "swiftpm/b2", pkgConfig: "libb2", aptProvider: "libb2-dev"),
    (envVar: "LIBARCHIVE_ENABLE_LIBCHARSET", define: "HAVE_LIBCHARSET", libName: "charset", moduleLoc: "swiftpm/charset", pkgConfig: "libcharset", aptProvider: "libcharset-dev"),
    (envVar: "LIBARCHIVE_ENABLE_LIBCRYPTO", define: "HAVE_LIBCRYPTO", libName: "crypto", moduleLoc: "swiftpm/crypto", pkgConfig: "libcrypto", aptProvider: "libcrypto-dev"),
    (envVar: "LIBARCHIVE_ENABLE_LIBEXPAT", define: "HAVE_LIBEXPAT", libName: "expat", moduleLoc: "swiftpm/expat", pkgConfig: "expat", aptProvider: "libexpat1-dev"),
    (envVar: "LIBARCHIVE_ENABLE_LIBLZ4", define: "HAVE_LIBLZ4", libName: "lz4", moduleLoc: "swiftpm/lz4", pkgConfig: "liblz4", aptProvider: "liblz4-dev"),
    (envVar: "LIBARCHIVE_ENABLE_LZMADEC", define: "HAVE_LIBLZMADEC", libName: "lzmadec", moduleLoc: "swiftpm/lzmadec", pkgConfig: "liblzmadec", aptProvider: "liblzmadec-dev"),
    (envVar: "LIBARCHIVE_ENABLE_LIBLZO2", define: "HAVE_LIBLZO2", libName: "lzo2", moduleLoc: "swiftpm/lzo2", pkgConfig: "liblzo2", aptProvider: "liblzo2-dev"),
    (envVar: "LIBARCHIVE_ENABLE_LIBMBEDCRYPTO", define: "HAVE_LIBMBEDCRYPTO", libName: "mbedcrypto", moduleLoc: "swiftpm/mbedcrypto", pkgConfig: "libmbedcrypto", aptProvider: "libmbedcrypto7"),
    (envVar: "LIBARCHIVE_ENABLE_LIBNETTLE", define: "HAVE_LIBNETTLE", libName: "nettle", moduleLoc: "swiftpm/nettle", pkgConfig: "nettle", aptProvider: "nettle-dev"),
    // (envVar: "LIBARCHIVE_ENABLE_LIBPCRE", define: "HAVE_LIBPCRE", libName: "pcre", moduleLoc: "swiftpm/pcre", pkgConfig: "libpcre", aptProvider: "libpcre-dev"),
    // (envVar: "LIBARCHIVE_ENABLE_LIBPCREPOSIX", define: "HAVE_LIBPCREPOSIX", libName: "pcreposix", moduleLoc: "swiftpm/pcreposix", pkgConfig: "libpcre-posix", aptProvider: "libpcre-dev"),
    (envVar: "LIBARCHIVE_ENABLE_LIBPCRE2", define: "HAVE_LIBPCRE2", libName: "pcre2", moduleLoc: "swiftpm/pcre2", pkgConfig: "libpcre2-8", aptProvider: "libpcre2-dev"),
    (envVar: "LIBARCHIVE_ENABLE_LIBPCRE2POSIX", define: "HAVE_LIBPCRE2POSIX", libName: "pcre2posix", moduleLoc: "swiftpm/pcre2posix", pkgConfig: "libpcre2-posix", aptProvider: "libpcre2-dev"),
    (envVar: "LIBARCHIVE_ENABLE_LIBXML2", define: "HAVE_LIBXML2", libName: "xml2", moduleLoc: "swiftpm/xml2", pkgConfig: "libxml-2.0", aptProvider: "libxml2-dev"),
]

for lib in libs {
    // Until we have traits, we use environment variables here to set which system libraries we want to use
    if let _ = ProcessInfo.processInfo.environment[lib.envVar] {
        libTarget.dependencies.append(.target(name: lib.libName))
        libTarget.cSettings!.append(CSetting.define(lib.define, to: "1"))
        package.targets.append(
            .systemLibrary(
                name: lib.libName,
                path: lib.moduleLoc,
                pkgConfig: lib.pkgConfig,
                providers: [.apt([lib.aptProvider])]
            )
        )
    }
}

#if os(Linux)
// TODO: we have to hard-code the default requirement of swiftly on zlib here until we have package traits to control this
libTarget.dependencies += ["zlib"]
package.targets += [
    .systemLibrary(
        name: "zlib",
        path: "swiftpm/zlib",
        pkgConfig: "zlib",
        providers: [.apt(["zlib1g-dev"])]
    ),
]
#endif
