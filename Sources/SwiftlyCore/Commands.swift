import Foundation
import SystemPackage

public enum SystemCommand {}

// This file contains a set of system commands that's used by Swiftly and its related tests and tooling

// Directory Service command line utility for macOS
// See dscl(1) for details
extension SystemCommand {
    public static func dscl(executable: Executable = DsclCommand.defaultExecutable, datasource: String? = nil) -> DsclCommand {
        DsclCommand(executable: executable, datasource: datasource)
    }

    public struct DsclCommand {
        public static var defaultExecutable: Executable { .name("dscl") }

        var executable: Executable
        var datasource: String?

        internal init(
            executable: Executable,
            datasource: String?
        ) {
            self.executable = executable
            self.datasource = datasource
        }

        func config() -> Configuration {
            var args: [String] = []

            if let datasource = self.datasource {
                args += [datasource]
            }

            return Configuration(
                executable: self.executable,
                arguments: Arguments(args),
                environment: .inherit
            )
        }

        public func read(path: FilePath? = nil, keys: [String]) -> ReadCommand {
            ReadCommand(dscl: self, path: path, keys: keys)
        }

        public func read(path: FilePath? = nil, keys: String...) -> ReadCommand {
            self.read(path: path, keys: keys)
        }

        public struct ReadCommand: Output {
            var dscl: DsclCommand
            var path: FilePath?
            var keys: [String]

            internal init(dscl: DsclCommand, path: FilePath?, keys: [String]) {
                self.dscl = dscl
                self.path = path
                self.keys = keys
            }

            public func config() -> Configuration {
                var c = self.dscl.config()

                var args = c.arguments.storage.map(\.description) + ["-read"]

                if let path = self.path {
                    args += [path.string] + self.keys
                }

                c.arguments = .init(args)

                return c
            }
        }
    }
}

extension SystemCommand.DsclCommand.ReadCommand {
    public func properties(_ p: Platform) async throws -> [(key: String, value: String)] {
        let output = try await self.output(p)
        guard let output else { return [] }

        var props: [(key: String, value: String)] = []
        for line in output.components(separatedBy: "\n") {
            if case let comps = line.components(separatedBy: ": "), comps.count == 2 {
                props.append((key: comps[0], value: comps[1]))
            }
        }
        return props
    }
}
