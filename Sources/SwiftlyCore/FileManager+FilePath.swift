import Foundation
import SystemPackage

public var cwd: FilePath {
    FileManager.default.currentDir
}

public var homeDir: FilePath {
    FileManager.default.homeDir
}

public var tmpDir: FilePath {
    FileManager.default.temporaryDir
}

public func fileExists(atPath: FilePath) async throws -> Bool {
    FileManager.default.fileExists(atPath: atPath)
}

public func remove(atPath: FilePath) async throws {
    try FileManager.default.removeItem(atPath: atPath)
}

public func move(atPath: FilePath, toPath: FilePath) async throws {
    try FileManager.default.moveItem(atPath: atPath, toPath: toPath)
}

public func copy(atPath: FilePath, toPath: FilePath) async throws {
    try FileManager.default.copyItem(atPath: atPath, toPath: toPath)
}

public func mkdir(atPath: FilePath, parents: Bool = false) async throws {
    try FileManager.default.createDir(atPath: atPath, withIntermediateDirectories: parents)
}

public func cat(atPath: FilePath) async throws -> Data {
    guard let data = FileManager.default.contents(atPath: atPath) else {
        throw SwiftlyError(message: "File at path \(atPath) could not be read")
    }

    return data
}

public func mktemp(ext: String? = nil) -> FilePath {
    FileManager.default.temporaryDir.appending("swiftly-\(UUID())\(ext ?? "")")
}

public func withTemporary<T>(files: FilePath..., f: () async throws -> T) async throws -> T {
    try await withTemporary(files: files, f: f)
}

public func withTemporary<T>(files: [FilePath], f: () async throws -> T) async throws -> T {
    do {
        let t: T = try await f()

        for f in files {
            try? await remove(atPath: f)
        }

        return t
    } catch {
        // Sort the list in case there are temporary files nested within other temporary files
        for f in files.map(\.string).sorted() {
            try? await remove(atPath: FilePath(f))
        }

        throw error
    }
}

public func create(file: FilePath, contents: Data?, mode: Int = 0) async throws {
    if mode != 0 {
        _ = FileManager.default.createFile(atPath: file.string, contents: contents, attributes: [.posixPermissions: mode])
    } else {
        _ = FileManager.default.createFile(atPath: file.string, contents: contents)
    }
}

public func ls(atPath: FilePath) async throws -> [String] {
    try FileManager.default.contentsOfDir(atPath: atPath)
}

public func readlink(atPath: FilePath) async throws -> FilePath {
    try FileManager.default.destinationOfSymbolicLink(atPath: atPath)
}

public func symlink(atPath: FilePath, linkPath: FilePath) async throws {
    try FileManager.default.createSymbolicLink(atPath: atPath, withDestinationPath: linkPath)
}

public func chmod(atPath: FilePath, mode: Int) async throws {
    try FileManager.default.setAttributes([.posixPermissions: mode], ofItemAtPath: atPath.string)
}

extension FileManager {
    public var currentDir: FilePath {
        FilePath(Self.default.currentDirectoryPath)
    }

    public var homeDir: FilePath {
        FilePath(Self.default.homeDirectoryForCurrentUser.path)
    }

    public func fileExists(atPath path: FilePath) -> Bool {
        Self.default.fileExists(atPath: path.string, isDirectory: nil)
    }

    public func removeItem(atPath path: FilePath) throws {
        try Self.default.removeItem(atPath: path.string)
    }

    public func moveItem(atPath: FilePath, toPath: FilePath) throws {
        try Self.default.moveItem(atPath: atPath.string, toPath: toPath.string)
    }

    public func copyItem(atPath: FilePath, toPath: FilePath) throws {
        try Self.default.copyItem(atPath: atPath.string, toPath: toPath.string)
    }

    public func deleteIfExists(atPath path: FilePath) throws {
        do {
            try Self.default.removeItem(atPath: path.string)
        } catch let error as NSError {
            guard error.domain == NSCocoaErrorDomain && error.code == CocoaError.fileNoSuchFile.rawValue else {
                throw error
            }
        }
    }

    public func createDir(atPath: FilePath, withIntermediateDirectories: Bool) throws {
        try Self.default.createDirectory(atPath: atPath.string, withIntermediateDirectories: withIntermediateDirectories)
    }

    public func contents(atPath: FilePath) -> Data? {
        Self.default.contents(atPath: atPath.string)
    }

    public var temporaryDir: FilePath {
        FilePath(Self.default.temporaryDirectory.path)
    }

    public func contentsOfDir(atPath: FilePath) throws -> [String] {
        try Self.default.contentsOfDirectory(atPath: atPath.string)
    }

    public func destinationOfSymbolicLink(atPath: FilePath) throws -> FilePath {
        FilePath(try Self.default.destinationOfSymbolicLink(atPath: atPath.string))
    }

    public func createSymbolicLink(atPath: FilePath, withDestinationPath: FilePath) throws {
        try Self.default.createSymbolicLink(atPath: atPath.string, withDestinationPath: withDestinationPath.string)
    }
}

extension Data {
    public func write(to path: FilePath, options: Data.WritingOptions = []) throws {
        try self.write(to: URL(fileURLWithPath: path.string), options: options)
    }

    public init(contentsOf path: FilePath) throws {
        try self.init(contentsOf: URL(fileURLWithPath: path.string))
    }
}

extension String {
    public func write(to path: FilePath, atomically: Bool, encoding enc: String.Encoding = .utf8) throws {
        try self.write(to: URL(fileURLWithPath: path.string), atomically: atomically, encoding: enc)
    }

    public init(contentsOf path: FilePath, encoding enc: String.Encoding = .utf8) throws {
        try self.init(contentsOf: URL(fileURLWithPath: path.string), encoding: enc)
    }
}

extension FilePath {
    public static func / (left: FilePath, right: String) -> FilePath {
        left.appending(right)
    }
}
