import Foundation
import Subprocess
import SystemPackage

public enum CommandLineError: Error {
    case invalidArgs
    case errorExit(exitCode: Int32, program: String)
    case unknownVersion
}

public protocol Runnable {
    func config() -> Configuration
}

extension Runnable {
    public func run<
        Input: InputProtocol,
        Output: OutputProtocol,
        Error: ErrorOutputProtocol
    >(
        environment: Environment = .inherit,
        input: Input = .none,
        output: Output,
        error: Error = .discarded
    ) async throws -> CollectedResult<Output, Error> {
        var c = self.config()
        // TODO: someday the configuration might have its own environment from the modeled commands. That will require this to be able to merge the environment from the commands with the provided environment.
        c.environment = environment

        let result = try await Subprocess.run(c, input: input, output: output, error: error)
        if !result.terminationStatus.isSuccess {
            throw RunProgramError(terminationStatus: result.terminationStatus, config: c)
        }

        return result
    }

    public func run(
        environment: Environment = .inherit,
        quiet: Bool = false,
    ) async throws {
        var c = self.config()
        // TODO: someday the configuration might have its own environment from the modeled commands. That will require this to be able to merge the environment from the commands with the provided environment.
        c.environment = environment

        if !quiet {
            let result = try await Subprocess.run(c, input: .standardInput, output: .standardOutput, error: .standardError)
            if !result.terminationStatus.isSuccess {
                throw RunProgramError(terminationStatus: result.terminationStatus, config: c)
            }
        } else {
            let result = try await Subprocess.run(c, input: .none, output: .discarded, error: .discarded)
            if !result.terminationStatus.isSuccess {
                throw RunProgramError(terminationStatus: result.terminationStatus, config: c)
            }
        }
    }
}

public protocol Output: Runnable {}

// TODO: look into making this something that can be Decodable (i.e. streamable)
extension Output {
    public func output(
        environment: Environment = .inherit,
        limit: Int
    ) async throws -> String? {
        var c = self.config()
        // TODO: someday the configuration might have its own environment from the modeled commands. That will require this to be able to merge the environment from the commands with the provided environment.
        c.environment = environment

        let output = try await Subprocess.run(
            self.config(),
            output: .string(limit: limit),
            error: .standardError
        )

        return output.standardOutput
    }
}

public enum SystemCommand {}
