import Foundation

nonisolated enum ResetSource: String, Codable, Equatable, Sendable {
    case official
    case communityConfirmed
    case estimated
}

nonisolated enum ResetTarget: Codable, Equatable, Hashable, Sendable {
    case gym(GymID)
    case wallZone(WallZoneID)
}

nonisolated struct ResetSummary: Identifiable, Codable, Equatable, Hashable, Sendable {
    var id: String {
        switch target {
        case .gym(let gymID): "gym-\(gymID.rawValue)-\(resetDate.timeIntervalSince1970)"
        case .wallZone(let zoneID): "zone-\(zoneID.rawValue)-\(resetDate.timeIntervalSince1970)"
        }
    }

    let target: ResetTarget
    let resetDate: Date
    let source: ResetSource
    let confirmationCount: Int
    let isEstimated: Bool
}
