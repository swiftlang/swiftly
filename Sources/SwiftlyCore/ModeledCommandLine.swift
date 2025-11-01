import Foundation
import Subprocess
import SystemPackage

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

extension Output {
    public func output(
        environment: Environment = .inherit,
        limit: Int,
        quiet: Bool = false
    ) async throws -> String? {
        var c = self.config()

        // TODO: someday the configuration might have its own environment from the modeled commands. That will require this to be able to merge the environment from the commands with the provided environment.
        c.environment = environment

        if !quiet {
            let result = try await Subprocess.run(
                self.config(),
                output: .string(limit: limit),
                error: .standardError
            )

            if !result.terminationStatus.isSuccess {
                throw RunProgramError(terminationStatus: result.terminationStatus, config: c)
            }

            return result.standardOutput
        } else {
            let result = try await Subprocess.run(
                self.config(),
                output: .string(limit: limit),
                error: .discarded
            )

            if !result.terminationStatus.isSuccess {
                throw RunProgramError(terminationStatus: result.terminationStatus, config: c)
            }

            return result.standardOutput
        }
    }

    public func output(
        environment: Environment = .inherit,
        limit _: Int,
        quiet: Bool = false,
        body: (AsyncBufferSequence) -> Void
    ) async throws {
        var c = self.config()

        // TODO: someday the configuration might have its own environment from the modeled commands. That will require this to be able to merge the environment from the commands with the provided environment.
        c.environment = environment

        if !quiet {
            let result = try await Subprocess.run(
                self.config(),
                error: .standardError
            ) { _, sequence in
                body(sequence)
            }

            if !result.terminationStatus.isSuccess {
                throw RunProgramError(terminationStatus: result.terminationStatus, config: c)
            }
        } else {
            let result = try await Subprocess.run(
                self.config(),
                error: .discarded
            ) { _, sequence in
                body(sequence)
            }

            if !result.terminationStatus.isSuccess {
                throw RunProgramError(terminationStatus: result.terminationStatus, config: c)
            }
        }
    }
}

public enum SystemCommand {}
