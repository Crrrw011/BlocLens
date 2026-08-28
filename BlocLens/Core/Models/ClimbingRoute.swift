import Foundation

nonisolated enum RouteLifecycle: String, Codable, Equatable, Sendable {
    case active
    case temporarilyHidden
    case archived
}

nonisolated enum RouteTerrain: String, CaseIterable, Codable, Equatable, Sendable {
    case slab
    case vertical
    case overhang
    case roof
    case cave
    case mixed
}

nonisolated enum RouteStyle: String, CaseIterable, Codable, Equatable, Sendable {
    case staticMovement = "static"
    case dynamic
    case technical
    case powerful
    case coordination
}

nonisolated struct RoutePhotoReference: Codable, Equatable, Hashable, Sendable {
    let referenceID: String
    let accessibilityDescription: String?
}

nonisolated struct ClimbingRoute: Identifiable, Codable, Equatable, Hashable, Sendable {
    let id: ClimbingRouteID
    let gymID: GymID
    let wallZoneID: WallZoneID
    let colour: String
    let terrain: RouteTerrain
    let styles: [RouteStyle]
    let subjectiveGrade: VGrade?
    let officialGrade: VGrade?
    let communityGradeSummary: CommunityGradeSummary
    let resetDate: Date?
    let expectedArchiveDate: Date?
    let isArchiveDateEstimated: Bool
    let lifecycle: RouteLifecycle
    let photoReference: RoutePhotoReference?
    let betaCount: Int

    var displayGrade: VGrade? {
        communityGradeSummary.displayGrade ?? subjectiveGrade ?? officialGrade
    }
}
