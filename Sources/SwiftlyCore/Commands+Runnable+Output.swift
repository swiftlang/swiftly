import Foundation
import SystemPackage

extension SystemCommand.dsclCommand.readCommand: Output {
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

extension SystemCommand.lipoCommand.createCommand: Runnable {}

extension SystemCommand.pkgbuildCommand: Runnable {}

extension SystemCommand.getentCommand: Output {
    public func entries(_ platform: Platform) async throws -> [[String]] {
        let output = try await output(platform)
        guard let output else { return [] }

        var entries: [[String]] = []
        for line in output.components(separatedBy: "\n") {
            entries.append(line.components(separatedBy: ":"))
        }
        return entries
    }
}

extension SystemCommand.gitCommand.logCommand: Output {}
extension SystemCommand.gitCommand.diffindexCommand: Runnable {}
extension SystemCommand.gitCommand.initCommand: Runnable {}
extension SystemCommand.gitCommand.commitCommand: Runnable {}

extension SystemCommand.tarCommand.createCommand: Runnable {}
extension SystemCommand.tarCommand.extractCommand: Runnable {}

extension SystemCommand.swiftCommand.packageCommand.resetCommand: Runnable {}
extension SystemCommand.swiftCommand.packageCommand.cleanCommand: Runnable {}
extension SystemCommand.swiftCommand.packageCommand.initCommand: Runnable {}
extension SystemCommand.swiftCommand.sdkCommand.installCommand: Runnable {}
extension SystemCommand.swiftCommand.sdkCommand.removeCommand: Runnable {}
extension SystemCommand.swiftCommand.buildCommand: Runnable {}

extension SystemCommand.makeCommand: Runnable {}
extension SystemCommand.makeCommand.installCommand: Runnable {}

extension SystemCommand.stripCommand: Runnable {}

extension SystemCommand.sha256sumCommand: Output {}

extension SystemCommand.productbuildCommand: Runnable {}

extension SystemCommand.gpgCommand.importCommand: Runnable {}
extension SystemCommand.gpgCommand.verifyCommand: Runnable {}

extension SystemCommand.pkgutilCommand.checksignatureCommand: Runnable {}
extension SystemCommand.pkgutilCommand.expandCommand: Runnable {}
extension SystemCommand.pkgutilCommand.forgetCommand: Runnable {}

extension SystemCommand.installerCommand: Runnable {}
