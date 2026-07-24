import Foundation

enum BuildChannel: String {
    case dev
    case beta
    case final

    static var current: BuildChannel {
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: "ArchiveAtlasBuildChannel") as? String,
            let channel = BuildChannel(rawValue: value)
        else {
            return .dev
        }
        return channel
    }

    var displayName: String {
        switch self {
        case .dev: "Local development"
        case .beta: "Beta"
        case .final: "Final"
        }
    }
}
