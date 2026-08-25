import Foundation

nonisolated enum WallType: String, CaseIterable, Codable, Equatable, Sendable {
    case slab
    case vertical
    case overhang
    case cave
    case mixed
}

nonisolated enum WallZoneAvailability: String, Codable, Equatable, Sendable {
    case active
    case temporarilyUnavailable
    case archived
}

nonisolated struct WallZone: Identifiable, Codable, Equatable, Hashable, Sendable {
    let id: WallZoneID
    let gymID: GymID
    let name: String
    let locationDescription: String
    let wallType: WallType
    let latestResetDate: Date?
    let routeCount: Int
    let betaCount: Int
    let availability: WallZoneAvailability
    let sortOrder: Int
}
