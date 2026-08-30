import Foundation

nonisolated struct GeoCoordinate: Codable, Equatable, Hashable, Sendable {
    let latitude: Double
    let longitude: Double
}

nonisolated enum GymFacility: String, CaseIterable, Codable, Hashable, Sendable {
    case parking
    case showers
    case trainingBoard
    case cafe
    case lockers
    case accessibleEntry
}

nonisolated enum HardSoftSummary: String, Codable, Equatable, Sendable {
    case soft
    case balanced
    case hard
    case insufficientData
}

nonisolated enum OperatingSummary: String, Codable, Equatable, Sendable {
    case developmentFixture
    case detailsUnavailable
}

nonisolated enum DataSourceState: String, Codable, Equatable, Sendable {
    case developmentFixture
    case official
    case community
    case estimated
}

nonisolated struct Gym: Identifiable, Codable, Equatable, Hashable, Sendable {
    let id: GymID
    let name: String
    let brandName: String
    let coordinate: GeoCoordinate
    let suburb: String
    let state: String
    let isVerified: Bool
    let betaCount: Int
    let latestResetDate: Date?
    let overallHardSoftSummary: HardSoftSummary
    let facilities: [GymFacility]
    let wallZoneIDs: [WallZoneID]
    let operatingSummary: OperatingSummary
    let dataSourceState: DataSourceState
    let googlePlaceID: String?
}
