import Foundation

nonisolated enum RouteLifecycle: String, Codable, Equatable, Sendable {
    case active
    case temporarilyHidden
    case archived
}

nonisolated struct RoutePhotoReference: Codable, Equatable, Hashable, Sendable {
    let referenceID: String
    let accessibilityDescription: String?
}

nonisolated struct ClimbingRoute: Identifiable, Codable, Equatable, Hashable, Sendable {
    let id: ClimbingRouteID
    let gymID: GymID
    let wallZoneID: WallZoneID
    let colourOrTag: String
    let officialGrade: VGrade?
    let communityGradeSummary: CommunityGradeSummary
    let resetDate: Date?
    let expectedArchiveDate: Date?
    let isArchiveDateEstimated: Bool
    let lifecycle: RouteLifecycle
    let photoReference: RoutePhotoReference?
    let betaCount: Int
}
