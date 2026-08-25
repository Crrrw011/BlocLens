import Foundation

nonisolated struct EntityID<Tag>: RawRepresentable, Codable, Hashable, Sendable, ExpressibleByStringLiteral {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(stringLiteral value: String) {
        rawValue = value
    }
}

nonisolated enum GymIDTag {}
nonisolated enum WallZoneIDTag {}
nonisolated enum ClimbingRouteIDTag {}
nonisolated enum BetaLinkIDTag {}
nonisolated enum LogbookEntryIDTag {}
nonisolated enum UserIDTag {}

typealias GymID = EntityID<GymIDTag>
typealias WallZoneID = EntityID<WallZoneIDTag>
typealias ClimbingRouteID = EntityID<ClimbingRouteIDTag>
typealias BetaLinkID = EntityID<BetaLinkIDTag>
typealias LogbookEntryID = EntityID<LogbookEntryIDTag>
typealias UserID = EntityID<UserIDTag>
