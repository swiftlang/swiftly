import CMsi
import SystemPackage

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
/// registered: no cached .msi files, no hard-coded component GUIDs, and nothing is written.
///
/// Windows Installer has no "components of this product" call, so this lists the swift.org
/// products, walks the components registered in the install contexts those products use, and
/// asks which products use each one. The key file of a component identifies the piece.
enum MsiEnumeration {
    static let installed: [InstalledSwift] = Self.findInstalledSwift()

    static func findInstalledSwift() -> [InstalledSwift] {
        let products = Dictionary(
            Self.installedProducts().filter { $0.publisher == "swift.org" }.map { ($0.code, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let paths = Self.installedPaths(of: products)

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

    private static let errorMoreData: UInt32 = 234

    private struct Product {
        let code: String
        let context: Int32
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
                var buffer = [MsiChar](repeating: 0, count: Int(capacity))
                var length = capacity
                let state = withWide(self.code) { code in
                    withWide(componentCode) { component in
                        withWide(self.sid) { sid in
                            MsiGetComponentPathExW(code, component, sid, self.context, &buffer, &length)
                        }
                    }
                }
                if state == MSI_INSTALLSTATE_MOREDATA {
                    capacity = length + 1
                    continue
                }
                return state == MSI_INSTALLSTATE_LOCAL ? string(from: buffer) : nil
            }
        }
    }

    /// Every product visible to the current user: their per-user installs plus per-machine ones.
    private static func installedProducts() -> [Product] {
        Self.enumerate { index, code, context, sid, sidLength in
            MsiEnumProductsExW(nil, nil, UInt32(MSI_CONTEXT_ALL), index, code, context, sid, sidLength)
        }.map { Product(code: $0.code, context: $0.context, sid: $0.sid) }
    }

    /// Key-file paths of every locally installed component that belongs to one of `products`,
    /// walking only the install contexts those products live in.
    private static func installedPaths(of products: [String: Product]) -> [String: [String]] {
        var paths: [String: [String]] = [:]
        let contexts = products.values.reduce(UInt32(0)) { $0 | UInt32($1.context) }
        guard contexts != 0 else {
            return paths
        }

        let components = Self.enumerate { index, code, context, sid, sidLength in
            MsiEnumComponentsExW(nil, contexts, index, code, context, sid, sidLength)
        }
        for component in components {
            let clients = withWide(component.code) { componentCode in
                Self.enumerate { index, code, context, sid, sidLength in
                    MsiEnumClientsExW(componentCode, nil, UInt32(MSI_CONTEXT_ALL), index, code, context, sid, sidLength)
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
        _ call: (UnsafeMutablePointer<MsiChar>, UnsafeMutablePointer<UInt32>) -> UInt32
    ) -> String? {
        var capacity: UInt32 = 256
        while true {
            var buffer = [MsiChar](repeating: 0, count: Int(capacity))
            var length = capacity
            let result = call(&buffer, &length)
            if result == Self.errorMoreData {
                capacity = length + 1
                continue
            }
            return result == 0 ? string(from: buffer) : nil
        }
    }

    /// Drives one of the MsiEnum*ExW functions, which each return a GUID, a context and a SID per index.
    /// Stops at the first error, which leaves the items found so far.
    private static func enumerate(
        _ call: (UInt32, UnsafeMutablePointer<MsiChar>, UnsafeMutablePointer<Int32>, UnsafeMutablePointer<MsiChar>, UnsafeMutablePointer<UInt32>) -> UInt32
    ) -> [(code: String, context: Int32, sid: String?)] {
        var items: [(code: String, context: Int32, sid: String?)] = []
        var index: UInt32 = 0
        while true {
            var code = [MsiChar](repeating: 0, count: 39)
            var context = Int32(MSI_CONTEXT_NONE)
            var sid = [MsiChar](repeating: 0, count: 256)
            var sidLength: UInt32 = 256
            let result = call(index, &code, &context, &sid, &sidLength)
            if result != 0 {
                break
            }
            let sidString = string(from: sid)
            items.append((string(from: code), context, sidString.isEmpty ? nil : sidString))
            index += 1
        }
        return items
    }
}

private func withWide<R>(_ s: String?, _ body: (UnsafePointer<MsiChar>?) -> R) -> R {
    guard let s else {
        return body(nil)
    }
    return s.withCString(encodedAs: UTF16.self) { body($0) }
}

private func string(from buffer: [MsiChar]) -> String {
    String(decoding: buffer.prefix { $0 != 0 }, as: UTF16.self)
}
