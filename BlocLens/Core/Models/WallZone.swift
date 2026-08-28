import Foundation

nonisolated enum WallKind: String, CaseIterable, Codable, Equatable, Sendable {
    case regularSetWall = "regular_set_wall"
    case sprayWall = "spray_wall"
    case compWall = "comp_wall"
}

nonisolated enum SurfaceMaterial: String, CaseIterable, Codable, Equatable, Sendable {
    case plywood
    case fibreglass
    case concrete
    case composite
    case other
}

nonisolated enum SurfaceTexture: String, CaseIterable, Codable, Equatable, Sendable {
    case smooth
    case lightlyTextured = "lightly_textured"
    case textured
    case rough
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
    let wallKind: WallKind
    let surfaceMaterial: SurfaceMaterial
    let surfaceTexture: SurfaceTexture
    let hasBoltHoles: Bool
    let createdBy: UserID?
    let latestResetDate: Date?
    let routeCount: Int
    let betaCount: Int
    let availability: WallZoneAvailability
    let sortOrder: Int
}
