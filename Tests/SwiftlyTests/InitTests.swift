import Foundation
@testable import Swiftly
@testable import SwiftlyCore
import SystemPackage
import Testing

@Suite struct InitTests {
    @Test func migrationsHasCurrentSwiftlyVersion() async throws {
        // If the current swiftly version isn't in the migration list then it should be added there to
        // support future self updates.
        #expect(!migrations.filter { $0.matches(SwiftlyCore.version) }.isEmpty)
    }

    @Test(.testHome(), arguments: ["/bin/bash", "/bin/zsh", "/bin/fish"]) func initFresh(_ shell: String) async throws {
        // GIVEN: a fresh user account without swiftly installed
        try? await fs.remove(atPath: Swiftly.currentPlatform.swiftlyConfigFile(SwiftlyTests.ctx))

        // AND: the user is using the bash shell
        var ctx = SwiftlyTests.ctx
        ctx.mockedShell = shell

        try await SwiftlyTests.$ctx.withValue(ctx) {
            let envScript: FilePath?
            if shell.hasSuffix("bash") || shell.hasSuffix("zsh") {
                envScript = Swiftly.currentPlatform.swiftlyHomeDir(SwiftlyTests.ctx) / "env.sh"
            } else if shell.hasSuffix("fish") {
                envScript = Swiftly.currentPlatform.swiftlyHomeDir(SwiftlyTests.ctx) / "env.fish"
            } else {
                envScript = nil
            }

            if let envScript {
                #expect(!(try await fs.exists(atPath: envScript)))
            }

            // WHEN: swiftly is invoked to init the user account and finish swiftly installation
            try await SwiftlyTests.runCommand(Init.self, ["init", "--assume-yes", "--skip-install"])

            // THEN: it creates a valid configuration at the correct version
            let config = try await Config.load()
            #expect(SwiftlyCore.version == config.version)

            // AND: it creates an environment script suited for the type of shell
            if let envScript {
                #expect(try await fs.exists(atPath: envScript))
                if let scriptContents = try? String(contentsOf: envScript) {
                    #expect(scriptContents.contains("SWIFTLY_HOME_DIR"))
                    #expect(scriptContents.contains("SWIFTLY_BIN_DIR"))
                    #expect(scriptContents.contains(Swiftly.currentPlatform.swiftlyHomeDir(SwiftlyTests.ctx).string))
                    #expect(scriptContents.contains(Swiftly.currentPlatform.swiftlyBinDir(SwiftlyTests.ctx).string))
                }
            }

            // AND: it sources the script from the user profile
            if let envScript {
                var foundSourceLine = false
                for p in [".profile", ".zprofile", ".bash_profile", ".bash_login", ".config/fish/conf.d/swiftly.fish"] {
                    let profile = SwiftlyTests.ctx.mockedHomeDir! / p
                    if try await fs.exists(atPath: profile) {
                        if let profileContents = try? String(contentsOf: profile), profileContents.contains(envScript.string) {
                            foundSourceLine = true
                            break
                        }
                    }
                }
                #expect(foundSourceLine)
            }
        }
    }

    @Test(.testHome()) func initOverwrite() async throws {
        // GIVEN: a user account with swiftly already installed
        try? await fs.remove(atPath: Swiftly.currentPlatform.swiftlyConfigFile(SwiftlyTests.ctx))

        try await SwiftlyTests.runCommand(Init.self, ["init", "--assume-yes", "--skip-install"])

        // Add some customizations to files and directories
        var config = try await Config.load()
        config.version = try SwiftlyVersion(parsing: "100.0.0")
        try config.save()

        try Data("".utf8).append(to: Swiftly.currentPlatform.swiftlyHomeDir(SwiftlyTests.ctx) / "foo.txt")
        try Data("".utf8).append(to: Swiftly.currentPlatform.swiftlyToolchainsDir(SwiftlyTests.ctx) / "foo.txt")

        // WHEN: swiftly is initialized with overwrite enabled
        try await SwiftlyTests.runCommand(Init.self, ["init", "--assume-yes", "--skip-install", "--overwrite"])

        // THEN: everything is overwritten in initialization
        config = try await Config.load()
        #expect(SwiftlyCore.version == config.version)
        #expect(!(try await fs.exists(atPath: Swiftly.currentPlatform.swiftlyHomeDir(SwiftlyTests.ctx) / "foo.txt")))
        #expect(!(try await fs.exists(atPath: Swiftly.currentPlatform.swiftlyToolchainsDir(SwiftlyTests.ctx) / "foo.txt")))
    }

    @Test(.testHome()) func initTwice() async throws {
        // GIVEN: a user account with swiftly already installed
        try? await fs.remove(atPath: Swiftly.currentPlatform.swiftlyConfigFile(SwiftlyTests.ctx))

        try await SwiftlyTests.runCommand(Init.self, ["init", "--assume-yes", "--skip-install"])

        // Add some customizations to files and directories
        var config = try await Config.load()
        config.version = try SwiftlyVersion(parsing: "100.0.0")
        try config.save()

        try Data("".utf8).append(to: Swiftly.currentPlatform.swiftlyHomeDir(SwiftlyTests.ctx) / "foo.txt")
        try Data("".utf8).append(to: Swiftly.currentPlatform.swiftlyToolchainsDir(SwiftlyTests.ctx) / "foo.txt")

        // WHEN: swiftly init is invoked a second time
        var threw = false
        do {
            try await SwiftlyTests.runCommand(Init.self, ["init", "--assume-yes", "--skip-install"])
        } catch {
            threw = true
        }

        // THEN: init fails
        #expect(threw)

        // AND: files were left intact
        config = try await Config.load()
        #expect(try SwiftlyVersion(parsing: "100.0.0") == config.version)
        #expect(try await fs.exists(atPath: Swiftly.currentPlatform.swiftlyHomeDir(SwiftlyTests.ctx) / "foo.txt"))
        #expect(try await fs.exists(atPath: Swiftly.currentPlatform.swiftlyToolchainsDir(SwiftlyTests.ctx) / "foo.txt"))
    }

    @Test(.testHome()) func initNoReleaseFallsBackToMainSnapshot() async throws {
        // GIVEN: a fresh account on a distribution with no release toolchain available
        try? await fs.remove(atPath: Swiftly.currentPlatform.swiftlyConfigFile(SwiftlyTests.ctx))

        var ctx = SwiftlyTests.ctx
        // ctx.mockedShell = "/bin/bash"
        ctx.httpClient = SwiftlyHTTPClient(
            httpRequestExecutor: MockToolchainDownloader(executables: [], releaseToolchains: []))

        try await SwiftlyTests.$ctx.withValue(ctx) {
            // WHEN: init runs without --skip-install and auto-confirms
            _ = try await SwiftlyTests.runWithMockedIO(Init.self, ["init", "--assume-yes"])

            // THEN: init completes and falls back to installing a main snapshot
            let config = try await Config.load()
            #expect(SwiftlyCore.version == config.version)
            #expect(!config.installedToolchains.isEmpty)
            let installed = config.installedToolchains.first
            guard let installed,
                  case let .snapshot(snapshot) = installed,
                  snapshot.branch == .main
            else {
                Issue.record("expected a main snapshot to be installed, got \(String(describing: installed))")
                return
            }
            // AND: the only installed toolchain becomes the global default
            #expect(config.inUse == installed)
        }
    }

    @Test(.testHome()) func initNoReleaseDeclineSnapshot() async throws {
        // GIVEN: a fresh account on a distribution with no release toolchain available
        try? await fs.remove(atPath: Swiftly.currentPlatform.swiftlyConfigFile(SwiftlyTests.ctx))

        var ctx = SwiftlyTests.ctx
        ctx.httpClient = SwiftlyHTTPClient(
            httpRequestExecutor: MockToolchainDownloader(executables: [], releaseToolchains: []))

        try await SwiftlyTests.$ctx.withValue(ctx) {
            // WHEN: init runs interactively, confirming the welcome prompt ("y") but
            // declining the main-snapshot fallback prompt ("n")
            _ = try await SwiftlyTests.runWithMockedIO(Init.self, ["init"], input: ["y", "n"])

            // THEN: swiftly is still initialized, but no toolchain was installed
            let config = try await Config.load()
            #expect(SwiftlyCore.version == config.version)
            #expect(config.installedToolchains.isEmpty)
            #expect(config.inUse == nil)
        }
    }

    private func posixSingleQuoted(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    @Test(
        .testHome("inject-a'$(touch PWNED)`id`;x"),
        arguments: ["/bin/zsh", "/bin/bash", "/bin/fish"],
        // arguments: ["/bin/bash", "/bin/zsh", "/bin/fish"],
    ) func initEnvShEscape(shell: String) async throws {
        // GIVEN: a fresh account whose swiftly home path contains shell metacharacters

        try? await fs.remove(atPath: Swiftly.currentPlatform.swiftlyConfigFile(SwiftlyTests.ctx))
        var ctx = SwiftlyTests.ctx
        ctx.mockedShell = shell

        let envFilename = shell.hasSuffix("fish") ? "env.fish" : "env.sh"

        try await SwiftlyTests.$ctx.withValue(ctx) {
            // WHEN: swiftly init generates env.sh
            try await SwiftlyTests.runCommand(Init.self, ["init", "--assume-yes", "--skip-install"])

            let envScript = Swiftly.currentPlatform.swiftlyHomeDir(SwiftlyTests.ctx) / envFilename
            #expect(try await fs.exists(atPath: envScript))
            let contents = try String(contentsOf: envScript)

            // THEN: every SWIFTLY_* export writes the path as a fully single-quoted,
            // escaped literal — no metacharacter can break out of the quoting.
            let home = Swiftly.currentPlatform.swiftlyHomeDir(SwiftlyTests.ctx).string
            let bin = Swiftly.currentPlatform.swiftlyBinDir(SwiftlyTests.ctx).string
            let toolchains = Swiftly.currentPlatform.swiftlyToolchainsDir(SwiftlyTests.ctx).string

            #expect(contents.contains("\(self.posixSingleQuoted(home))"))
            #expect(contents.contains("\(self.posixSingleQuoted(bin))"))
            #expect(contents.contains("\(self.posixSingleQuoted(toolchains))"))

            #expect(!contents.contains("\(home)"))
            #expect(!contents.contains("\(toolchains)"))
        }
    }

    @Test(
        .testHome(),
        arguments: [
            ("bash", 0),
            ("bash", 1),
            ("fish", 0),
            ("fish", 1),
        ]
    )
    func initUpgrade(_ shell: String, _ envVersion: Int) async throws {
        let homeDirRaw = Swiftly.currentPlatform.swiftlyHomeDir(SwiftlyTests.ctx).string
        let binDirRaw = Swiftly.currentPlatform.swiftlyBinDir(SwiftlyTests.ctx).string
        let toolchainsDirRaw = Swiftly.currentPlatform.swiftlyToolchainsDir(SwiftlyTests.ctx).string

        // Create a fresh account and install an older Swiftly env.sh
        let versions: [String: [String]] = [
            "fish": [
                // old, but not quite as old format
                """
                set -x SWIFTLY_HOME_DIR "\(homeDirRaw)"
                set -x SWIFTLY_BIN_DIR "\(binDirRaw)"
                set -x SWIFTLY_TOOLCHAINS_DIR "\(toolchainsDirRaw)"

                # Remove SWIFTLY_BIN_DIR from PATH if present, then prepend it
                while set -l index (contains -i "$SWIFTLY_BIN_DIR" $PATH)
                    set -e PATH[$index]
                end
                set -x PATH "$SWIFTLY_BIN_DIR" $PATH

                """,
                // Old old format
                """
                set -x SWIFTLY_HOME_DIR "\(homeDirRaw)"
                set -x SWIFTLY_BIN_DIR "\(binDirRaw)"
                set -x SWIFTLY_TOOLCHAINS_DIR "\(toolchainsDirRaw)"
                if not contains "$SWIFTLY_BIN_DIR" $PATH
                    set -x PATH "$SWIFTLY_BIN_DIR" $PATH
                end

                """,
            ],
            "bash": [
                """
                export SWIFTLY_HOME_DIR="\(homeDirRaw)"
                export SWIFTLY_BIN_DIR="\(binDirRaw)"
                export SWIFTLY_TOOLCHAINS_DIR="\(toolchainsDirRaw)"
                if [[ ":$PATH:" != *":$SWIFTLY_BIN_DIR:"* ]]; then
                    export PATH="$SWIFTLY_BIN_DIR:$PATH"
                fi

                """,
                """
                export SWIFTLY_HOME_DIR="\(homeDirRaw)"
                export SWIFTLY_BIN_DIR="\(binDirRaw)"
                export SWIFTLY_TOOLCHAINS_DIR="\(toolchainsDirRaw)"

                # Remove SWIFTLY_BIN_DIR from PATH if present, then prepend it
                PATH="${PATH//:$SWIFTLY_BIN_DIR/}"
                PATH="${PATH/#$SWIFTLY_BIN_DIR:/}"
                export PATH="$SWIFTLY_BIN_DIR:$PATH"

                """,
            ],
        ]

        // GIVEN: an older swiftly install whose config version is migratable, and an
        // env file written in one of the recognized old formats.
        var config = try await Config.load()
        config.version = try SwiftlyVersion(parsing: "1.0.0")
        try config.save()

        let envFilename = shell == "fish" ? "env.fish" : "env.sh"
        let envFile = Swiftly.currentPlatform.swiftlyHomeDir(SwiftlyTests.ctx) / envFilename
        let oldContents = versions[shell]![envVersion]
        try oldContents.write(to: envFile, atomically: true, encoding: .utf8)
        #expect(try String(contentsOf: envFile) == oldContents)

        // WHEN: swiftly init runs without --overwrite, taking the upgrade path
        try await SwiftlyTests.runCommand(Init.self, ["init", "--assume-yes", "--skip-install"])

        // THEN: the env file is rewritten to the current, shell-escaped format
        let expected: String
        if shell == "fish" {
            expected = """
            set -x SWIFTLY_HOME_DIR \(self.posixSingleQuoted(homeDirRaw))
            set -x SWIFTLY_BIN_DIR \(self.posixSingleQuoted(binDirRaw))
            set -x SWIFTLY_TOOLCHAINS_DIR \(self.posixSingleQuoted(toolchainsDirRaw))

            # Remove SWIFTLY_BIN_DIR from PATH if present, then prepend it
            while set -l index (contains -i "$SWIFTLY_BIN_DIR" $PATH)
                set -e PATH[$index]
            end
            set -x PATH "$SWIFTLY_BIN_DIR" $PATH

            """
        } else {
            expected = """
            export SWIFTLY_HOME_DIR=\(self.posixSingleQuoted(homeDirRaw))
            export SWIFTLY_BIN_DIR=\(self.posixSingleQuoted(binDirRaw))
            export SWIFTLY_TOOLCHAINS_DIR=\(self.posixSingleQuoted(toolchainsDirRaw))

            # Remove SWIFTLY_BIN_DIR from PATH if present, then prepend it
            PATH="${PATH//:$SWIFTLY_BIN_DIR/}"
            PATH="${PATH/#$SWIFTLY_BIN_DIR:/}"
            export PATH="$SWIFTLY_BIN_DIR:$PATH"

            """
        }

        #expect(try String(contentsOf: envFile) == expected)

        // AND: the config version is bumped to the current swiftly version
        config = try await Config.load()
        #expect(config.version == SwiftlyCore.version)
    }
}
