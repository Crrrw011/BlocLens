import Foundation

nonisolated struct GymRecord: Codable, Equatable, Sendable {
    let id: UUID
    let name: String
    let brandName: String?
    let latitude: Double
    let longitude: Double
    let suburb: String
    let state: String
    let isVerified: Bool
    let dataSource: String
    let betaCount: Int?
    let latestResetDate: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, latitude, longitude, suburb, state
        case brandName = "brand_name"
        case isVerified = "is_verified"
        case dataSource = "data_source"
        case betaCount = "beta_count"
        case latestResetDate = "latest_reset_date"
    }

    func domain(
        facilities: [GymFacilityRecord],
        wallZones: [WallZoneRecord],
        hardSoft: HardSoftSummary,
        operatingSummary: OperatingSummary = .detailsUnavailable
    ) throws -> Gym {
        let source: DataSourceState
        switch dataSource {
        case "development_fixture": source = .developmentFixture
        case "official": source = .official
        case "community", "public_source", "google_places": source = .community
        default:
            throw RemoteMappingError.unsupportedValue(field: "gyms.data_source", value: dataSource)
        }

        let matchingZones = wallZones.filter { $0.gymID == id }
        return try Gym(
            id: GymID(rawValue: RemoteIdentifier.domainString(id)),
            name: name,
            brandName: brandName ?? name,
            coordinate: GeoCoordinate(latitude: latitude, longitude: longitude),
            suburb: suburb,
            state: state,
            isVerified: isVerified,
            betaCount: max(0, betaCount ?? 0),
            latestResetDate: latestResetDate,
            overallHardSoftSummary: hardSoft,
            facilities: facilities
                .filter { $0.gymID == id && $0.isAvailable }
                .map { try $0.domain() },
            wallZoneIDs: matchingZones
                .sorted { $0.displayOrder < $1.displayOrder }
                .map { WallZoneID(rawValue: RemoteIdentifier.domainString($0.id)) },
            operatingSummary: operatingSummary,
            dataSourceState: source
        )
    }
}

nonisolated struct GymFacilityRecord: Codable, Equatable, Sendable {
    let gymID: UUID
    let facility: String
    let isAvailable: Bool

    enum CodingKeys: String, CodingKey {
        case facility
        case gymID = "gym_id"
        case isAvailable = "is_available"
    }

    func domain() throws -> GymFacility {
        switch facility {
        case "parking": .parking
        case "showers": .showers
        case "training_board": .trainingBoard
        case "cafe": .cafe
        case "lockers": .lockers
        case "accessible_entry": .accessibleEntry
        default: throw RemoteMappingError.unsupportedValue(field: "gym_facilities.facility", value: facility)
        }
    }
}

nonisolated struct WallZoneRecord: Codable, Equatable, Sendable {
    let id: UUID
    let gymID: UUID
    let name: String
    let locationDescription: String?
    let wallKind: String?
    let surfaceMaterial: String?
    let surfaceTexture: String?
    let hasBoltHoles: Bool?
    let createdBy: UUID?
    let displayOrder: Int
    let availability: String
    let lastResetDate: Date?
    let currentRouteCount: Int?
    let betaCount: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, availability
        case gymID = "gym_id"
        case locationDescription = "location_description"
        case wallKind = "wall_kind"
        case surfaceMaterial = "surface_material"
        case surfaceTexture = "surface_texture"
        case hasBoltHoles = "has_bolt_holes"
        case createdBy = "created_by"
        case displayOrder = "display_order"
        case lastResetDate = "last_reset_date"
        case currentRouteCount = "current_route_count"
        case betaCount = "beta_count"
    }

    func domain() throws -> WallZone {
        let domainWallKind: WallKind
        switch wallKind {
        case "spray_wall": domainWallKind = .sprayWall
        case "comp_wall": domainWallKind = .compWall
        case "regular_set_wall", nil: domainWallKind = .regularSetWall
        default: throw RemoteMappingError.unsupportedValue(field: "wall_zones.wall_kind", value: wallKind ?? "")
        }

        let domainAvailability: WallZoneAvailability
        switch availability {
        case "active": domainAvailability = .active
        case "temporarily_unavailable": domainAvailability = .temporarilyUnavailable
        case "archived": domainAvailability = .archived
        default:
            throw RemoteMappingError.unsupportedValue(
                field: "wall_zones.availability",
                value: availability
            )
        }

        let domainMaterial: SurfaceMaterial
        switch surfaceMaterial {
        case "plywood", nil: domainMaterial = .plywood
        case "fibreglass": domainMaterial = .fibreglass
        case "concrete": domainMaterial = .concrete
        case "composite": domainMaterial = .composite
        case "other": domainMaterial = .other
        default: domainMaterial = .other
        }

        let domainTexture: SurfaceTexture
        switch surfaceTexture {
        case "smooth": domainTexture = .smooth
        case "lightly_textured", nil: domainTexture = .lightlyTextured
        case "textured": domainTexture = .textured
        case "rough": domainTexture = .rough
        default: domainTexture = .lightlyTextured
        }

        return WallZone(
            id: WallZoneID(rawValue: RemoteIdentifier.domainString(id)),
            gymID: GymID(rawValue: RemoteIdentifier.domainString(gymID)),
            name: name,
            locationDescription: locationDescription ?? "",
            wallKind: domainWallKind,
            surfaceMaterial: domainMaterial,
            surfaceTexture: domainTexture,
            hasBoltHoles: hasBoltHoles ?? true,
            createdBy: createdBy.map { UserID(rawValue: RemoteIdentifier.domainString($0)) },
            latestResetDate: lastResetDate,
            routeCount: max(0, currentRouteCount ?? 0),
            betaCount: max(0, betaCount ?? 0),
            availability: domainAvailability,
            sortOrder: max(0, displayOrder)
        )
    }
}

nonisolated struct ResetRecord: Codable, Equatable, Sendable {
    let id: UUID
    let gymID: UUID
    let wallZoneID: UUID?
    let resetDate: Date
    let source: String
    let confirmationCount: Int
    let isEstimated: Bool

    enum CodingKeys: String, CodingKey {
        case id, source
        case gymID = "gym_id"
        case wallZoneID = "wall_zone_id"
        case resetDate = "reset_date"
        case confirmationCount = "confirmation_count"
        case isEstimated = "is_estimated"
    }

    func domain() throws -> ResetSummary {
        let domainSource: ResetSource
        switch source {
        case "official": domainSource = .official
        case "community_confirmed": domainSource = .communityConfirmed
        case "estimated": domainSource = .estimated
        default: throw RemoteMappingError.unsupportedValue(field: "reset_events.source", value: source)
        }

        let target: ResetTarget = if let wallZoneID {
            .wallZone(WallZoneID(rawValue: RemoteIdentifier.domainString(wallZoneID)))
        } else {
            .gym(GymID(rawValue: RemoteIdentifier.domainString(gymID)))
        }
        return ResetSummary(
            target: target,
            resetDate: resetDate,
            source: domainSource,
            confirmationCount: max(0, confirmationCount),
            isEstimated: isEstimated
        )
    }
}

nonisolated struct GymHardSoftBandRecord: Codable, Equatable, Sendable {
    let gradeBand: String
    let eligibleRouteCount: Int
    let medianGradeDelta: Double?
    let assessment: String

    enum CodingKeys: String, CodingKey {
        case gradeBand = "grade_band"
        case eligibleRouteCount = "eligible_route_count"
        case medianGradeDelta = "median_grade_delta"
        case assessment
    }
}

nonisolated enum GymHardSoftMapping {
    static func overallSummary(from bands: [GymHardSoftBandRecord]) throws -> HardSoftSummary {
        guard let overall = bands.first(where: { $0.gradeBand == "Overall" }) else {
            throw RemoteMappingError.inconsistentData(
                "gym_hard_soft_summary is missing the Overall band."
            )
        }
        switch overall.assessment {
        case "soft": return .soft
        case "balanced": return .balanced
        case "hard": return .hard
        case "not_enough_community_data": return .insufficientData
        default:
            throw RemoteMappingError.unsupportedValue(
                field: "gym_hard_soft_summary.assessment",
                value: overall.assessment
            )
        }
    }
}
