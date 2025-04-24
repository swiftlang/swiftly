import Foundation
import SystemPackage

public enum CommandLineError: Error {
    case invalidArgs
    case errorExit(exitCode: Int32, program: String)
    case unknownVersion
}

// This section is a clone of the Configuration type from the new Subprocess package, until we can depend on that package.
public struct Configuration: Sendable {
    /// The executable to run.
    public var executable: Executable
    /// The arguments to pass to the executable.
    public var arguments: Arguments
    /// The environment to use when running the executable.
    public var environment: Environment
}

public struct Executable: Sendable, Hashable {
    internal enum Storage: Sendable, Hashable {
        case executable(String)
        case path(FilePath)
    }

    internal let storage: Storage

    private init(_config: Storage) {
        self.storage = _config
    }

    /// Locate the executable by its name.
    /// `Subprocess` will use `PATH` value to
    /// determine the full path to the executable.
    public static func name(_ executableName: String) -> Self {
        .init(_config: .executable(executableName))
    }

    /// Locate the executable by its full path.
    /// `Subprocess` will use this  path directly.
    public static func path(_ filePath: FilePath) -> Self {
        .init(_config: .path(filePath))
    }
}

public struct Environment: Sendable, Hashable {
    internal enum Configuration: Sendable, Hashable {
        case inherit([String: String])
        case custom([String: String])
    }

    internal let config: Configuration

    init(config: Configuration) {
        self.config = config
    }

    /// Child process should inherit the same environment
    /// values from its parent process.
    public static var inherit: Self {
        .init(config: .inherit([:]))
    }

    /// Override the provided `newValue` in the existing `Environment`
    public func updating(_ newValue: [String: String]) -> Self {
        .init(config: .inherit(newValue))
    }

    /// Use custom environment variables
    public static func custom(_ newValue: [String: String]) -> Self {
        .init(config: .custom(newValue))
    }
}

internal enum StringOrRawBytes: Sendable, Hashable {
    case string(String)

    var stringValue: String? {
        switch self {
        case let .string(string):
            return string
        }
    }

    var description: String {
        switch self {
        case let .string(string):
            return string
        }
    }

    var count: Int {
        switch self {
        case let .string(string):
            return string.count
        }
    }

    func hash(into hasher: inout Hasher) {
        // If Raw bytes is valid UTF8, hash it as so
        switch self {
        case let .string(string):
            hasher.combine(string)
        }
    }
}

public struct Arguments: Sendable, ExpressibleByArrayLiteral, Hashable {
    public typealias ArrayLiteralElement = String

    internal let storage: [StringOrRawBytes]

    /// Create an Arguments object using the given literal values
    public init(arrayLiteral elements: String...) {
        self.storage = elements.map { .string($0) }
    }

    /// Create an Arguments object using the given array
    public init(_ array: [String]) {
        self.storage = array.map { .string($0) }
    }
}

public protocol Runnable {
    func config() -> Configuration
}

extension Runnable {
    public func run(_ p: Platform, quiet: Bool = false) async throws {
        let c = self.config()
        let executable = switch c.executable.storage {
        case let .executable(name):
            name
        case let .path(p):
            p.string
        }
        let args = c.arguments.storage.map(\.description)
        var env: [String: String] = ProcessInfo.processInfo.environment
        switch c.environment.config {
        case let .inherit(newValue):
            for (key, value) in newValue {
                env[key] = value
            }
        case let .custom(newValue):
            env = newValue
        }
        try await p.runProgram([executable] + args, quiet: quiet, env: env)
    }
}

public protocol Output {
    func config() -> Configuration
}

// TODO: look into making this something that can be Decodable (i.e. streamable)
extension Output {
    public func output(_ p: Platform) async throws -> String? {
        let c = self.config()
        let executable = switch c.executable.storage {
        case let .executable(name):
            name
        case let .path(p):
            p.string
        }
        let args = c.arguments.storage.map(\.description)
        var env: [String: String] = ProcessInfo.processInfo.environment
        switch c.environment.config {
        case let .inherit(newValue):
            for (key, value) in newValue {
                env[key] = value
            }
        case let .custom(newValue):
            env = newValue
        }
        return try await p.runProgramOutput(executable, args, env: env)
    }
}
