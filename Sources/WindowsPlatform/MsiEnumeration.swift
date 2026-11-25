import CMsi
import Foundation
import SystemPackage
import WinSDK

/// A Swift version the official Windows installer registered, with where each of its pieces lives.
struct InstalledSwift: Equatable {
    /// The products' `VersionString`, such as "6.4.1".
    var version: String
    /// The toolchain root, the folder that holds `usr\bin\swift.exe`.
    var toolchain: FilePath?
    /// SDK folders, such as `...\Windows.platform\Developer\SDKs\Windows.sdk`.
    var sdks: [FilePath]
    /// The runtime's `usr\bin`, which holds `swiftCore.dll`.
    var runtime: FilePath?
}

/// Finds installed Swift toolchains, SDKs and runtimes using only what Windows Installer has
/// registered: no cached .msi files and no hard-coded component GUIDs.
///
/// Windows Installer has no "components of this product" call, so this lists the swift.org
/// products, walks the components registered in the install contexts those products use, and
/// asks which products use each one. The key file of a component identifies the piece.
///
/// The walk takes seconds, so its result is saved to a file and reused while the set of swift.org
/// products stays the same. A product code always installs the same thing, so installing,
/// upgrading or removing Swift changes the set and leads to a new walk.
enum MsiEnumeration {
    /// The installed Swift versions, read from `cacheFile` when it was saved for the swift.org
    /// products installed now, or found by walking Windows Installer and then saved there.
    static func installed(cacheFile: FilePath) -> [InstalledSwift] {
        var complete = true
        let products = Self.swiftProducts(complete: &complete)
        let codes = products.keys.sorted()
        if complete, let cache = Cache.read(from: cacheFile), cache.products == codes, cache.pathsExist {
            return cache.installed
        }

        let installed = Self.findInstalledSwift(products, complete: &complete)
        // A walk cut short by an error would otherwise leave toolchains out until Swift is next
        // installed or removed.
        if complete {
            Cache(products: codes, installed: installed).write(to: cacheFile)
        }
        return installed
    }

    /// The swift.org products visible to the current user, by product code.
    private static func swiftProducts(complete: inout Bool) -> [String: Product] {
        Dictionary(
            Self.installedProducts(complete: &complete).filter { $0.publisher == "swift.org" }.map { ($0.code, $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    /// Walks the components of `products`. Sets `complete` to false if a Windows Installer call
    /// failed partway, and returns what was found before that.
    private static func findInstalledSwift(_ products: [String: Product], complete: inout Bool) -> [InstalledSwift] {
        let paths = Self.installedPaths(of: products, complete: &complete)

        var byVersion: [String: InstalledSwift] = [:]
        for product in products.values {
            let version = product.version
            var entry = byVersion[version] ?? InstalledSwift(version: version, toolchain: nil, sdks: [], runtime: nil)
            for path in paths[product.code] ?? [] {
                switch Self.piece(forKeyFile: path) {
                case let .toolchain(root):
                    // Pick deterministically if two variants of one version are installed.
                    if entry.toolchain == nil || root.string < entry.toolchain!.string {
                        entry.toolchain = root
                    }
                case let .sdk(folder):
                    entry.sdks.append(folder)
                case let .runtime(bin):
                    entry.runtime = bin
                case nil:
                    continue
                }
            }
            byVersion[version] = entry
        }

        return byVersion.values
            .map { var e = $0
                e.sdks.sort { $0.string < $1.string }
                return e
            }
            .sorted { $0.version < $1.version }
    }

    /// A walk's result, with the swift.org product codes it was found for.
    private struct Cache: Codable {
        struct Entry: Codable {
            var version: String
            var toolchain: String?
            var sdks: [String]
            var runtime: String?
        }

        var products: [String]
        var entries: [Entry]

        init(products: [String], installed: [InstalledSwift]) {
            self.products = products
            self.entries = installed.map {
                Entry(version: $0.version, toolchain: $0.toolchain?.string, sdks: $0.sdks.map(\.string), runtime: $0.runtime?.string)
            }
        }

        var installed: [InstalledSwift] {
            self.entries.map {
                InstalledSwift(
                    version: $0.version,
                    toolchain: $0.toolchain.map { FilePath($0) },
                    sdks: $0.sdks.map { FilePath($0) },
                    runtime: $0.runtime.map { FilePath($0) }
                )
            }
        }

        /// Whether every folder is still there. Deleting one outside Windows Installer leaves the
        /// product codes as they were.
        var pathsExist: Bool {
            self.entries.allSatisfy { entry in
                ([entry.toolchain, entry.runtime].compactMap { $0 } + entry.sdks).allSatisfy {
                    FileManager.default.fileExists(atPath: $0)
                }
            }
        }

        static func read(from file: FilePath) -> Cache? {
            guard let data = FileManager.default.contents(atPath: file.string) else {
                return nil
            }
            return try? JSONDecoder().decode(Cache.self, from: data)
        }

        /// Best effort: if the file can't be written, the next run walks again.
        func write(to file: FilePath) {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            guard let data = try? encoder.encode(self) else {
                return
            }
            try? data.write(to: URL(fileURLWithPath: file.string), options: .atomic)
        }
    }

    enum Piece: Equatable {
        case toolchain(FilePath)
        case sdk(FilePath)
        case runtime(FilePath)
    }

    /// Which piece a component's key file identifies, and the folder that piece lives in.
    static func piece(forKeyFile path: String) -> Piece? {
        let file = FilePath(path)
        switch file.lastComponent?.string.lowercased() {
        case "swift.exe":
            // <root>\usr\bin\swift.exe
            return .toolchain(file.removingLastComponent().removingLastComponent().removingLastComponent())
        case "sdksettings.json":
            // <sdk>\SDKSettings.json
            return .sdk(file.removingLastComponent())
        case "swiftcore.dll":
            // Runtimes\<version>\usr\bin\swiftCore.dll
            return .runtime(file.removingLastComponent())
        default:
            return nil
        }
    }

    // MARK: - Windows Installer calls

    private struct Product {
        let code: String
        let context: MSIINSTALLCONTEXT
        let sid: String?

        func info(_ property: String) -> String? {
            MsiEnumeration.readString { buffer, length in
                withWide(self.code) { code in
                    withWide(self.sid) { sid in
                        withWide(property) { property in
                            MsiGetProductInfoExW(code, sid, self.context, property, buffer, length)
                        }
                    }
                }
            }
        }

        var version: String { self.info("VersionString") ?? "" }
        var publisher: String { self.info("Publisher") ?? "" }

        /// Full path of the key file of `componentCode`, if it's installed locally.
        func componentPath(_ componentCode: String) -> String? {
            var capacity: UInt32 = 512
            while true {
                var buffer = [WCHAR](repeating: 0, count: Int(capacity))
                var length = capacity
                let state = withWide(self.code) { code in
                    withWide(componentCode) { component in
                        withWide(self.sid) { sid in
                            MsiGetComponentPathExW(code, component, sid, self.context, &buffer, &length)
                        }
                    }
                }
                if state == INSTALLSTATE_MOREDATA {
                    capacity = length + 1
                    continue
                }
                return state == INSTALLSTATE_LOCAL ? string(from: buffer) : nil
            }
        }
    }

    /// Every product visible to the current user: their per-user installs plus per-machine ones.
    private static func installedProducts(complete: inout Bool) -> [Product] {
        Self.enumerate(complete: &complete) { index, code, context, sid, sidLength in
            MsiEnumProductsExW(nil, nil, UInt32(MSIINSTALLCONTEXT_ALL.rawValue), index, code, context, sid, sidLength)
        }.map { Product(code: $0.code, context: $0.context, sid: $0.sid) }
    }

    /// Key-file paths of every locally installed component that belongs to one of `products`,
    /// walking only the install contexts those products live in.
    private static func installedPaths(of products: [String: Product], complete: inout Bool) -> [String: [String]] {
        var paths: [String: [String]] = [:]
        let contexts = products.values.reduce(UInt32(0)) { $0 | UInt32($1.context.rawValue) }
        guard contexts != 0 else {
            return paths
        }

        let components = Self.enumerate(complete: &complete) { index, code, context, sid, sidLength in
            MsiEnumComponentsExW(nil, contexts, index, code, context, sid, sidLength)
        }
        for component in components {
            let clients = withWide(component.code) { componentCode in
                Self.enumerate(complete: &complete) { index, code, context, sid, sidLength in
                    MsiEnumClientsExW(componentCode, nil, UInt32(MSIINSTALLCONTEXT_ALL.rawValue), index, code, context, sid, sidLength)
                }
            }
            for client in clients {
                guard let product = products[client.code], let path = product.componentPath(component.code) else {
                    continue
                }
                paths[client.code, default: []].append(path)
            }
        }
        return paths
    }

    /// Calls an MSI "fill this buffer" function, growing the buffer on ERROR_MORE_DATA.
    fileprivate static func readString(
        _ call: (UnsafeMutablePointer<WCHAR>, UnsafeMutablePointer<UInt32>) -> UInt32
    ) -> String? {
        var capacity: UInt32 = 256
        while true {
            var buffer = [WCHAR](repeating: 0, count: Int(capacity))
            var length = capacity
            let result = call(&buffer, &length)
            if result == ERROR_MORE_DATA {
                capacity = length + 1
                continue
            }
            return result == ERROR_SUCCESS ? string(from: buffer) : nil
        }
    }

    /// Drives one of the MsiEnum*ExW functions, which each return a GUID, a context and a SID per index.
    /// Stops at the first error, which leaves the items found so far. An error other than the end of
    /// the list sets `complete` to false.
    private static func enumerate(
        complete: inout Bool,
        _ call: (UInt32, UnsafeMutablePointer<WCHAR>, UnsafeMutablePointer<MSIINSTALLCONTEXT>, UnsafeMutablePointer<WCHAR>, UnsafeMutablePointer<UInt32>) -> UInt32
    ) -> [(code: String, context: MSIINSTALLCONTEXT, sid: String?)] {
        var items: [(code: String, context: MSIINSTALLCONTEXT, sid: String?)] = []
        var index: UInt32 = 0
        while true {
            var code = [WCHAR](repeating: 0, count: 39)
            var context = MSIINSTALLCONTEXT_NONE
            var sid = [WCHAR](repeating: 0, count: 256)
            var sidLength: UInt32 = 256
            let result = call(index, &code, &context, &sid, &sidLength)
            if result != ERROR_SUCCESS {
                if result != UInt32(ERROR_NO_MORE_ITEMS) {
                    complete = false
                }
                break
            }
            let sidString = string(from: sid)
            items.append((string(from: code), context, sidString.isEmpty ? nil : sidString))
            index += 1
        }
        return items
    }
}

private func withWide<R>(_ s: String?, _ body: (UnsafePointer<WCHAR>?) -> R) -> R {
    guard let s else {
        return body(nil)
    }
    return s.withCString(encodedAs: UTF16.self) { body($0) }
}

private func string(from buffer: [WCHAR]) -> String {
    String(decoding: buffer.prefix { $0 != 0 }, as: UTF16.self)
}
