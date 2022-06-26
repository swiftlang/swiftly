enum ToolchainVersion {
    enum SnapshotBranch {
        case main
        case release(major: Int, minor: Int)
    }

    struct StableRelease {
        let major: Int
        let minor: Int
        let patch: Int
    }

    case stable(StableRelease)
    case snapshot(branch: SnapshotBranch, date: String)
}

extension ToolchainVersion: CustomStringConvertible {
    var description: String {
        switch self {
        case let .stable(release):
            return "\(release.major).\(release.minor).\(release.patch)"
        case let .snapshot(.main, date):
            return "main-snapshot-\(date)"
        case let .snapshot(.release(major, minor), date):
            return "\(major).\(minor)-snapshot-\(date)"
        }
    }
}
