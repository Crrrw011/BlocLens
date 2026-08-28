import Foundation

nonisolated struct RouteRecord: Codable, Equatable, Sendable {
    let id: UUID
    let gymID: UUID
    let wallZoneID: UUID
    let colour: String?
    let terrain: String?
    let styles: [String]?
    let subjectiveGrade: Int?
    let gymGrade: Int?
    let lifecycle: String
    let setDate: Date?
    let estimatedArchiveDate: Date?
    let isArchiveDateEstimated: Bool
    let archivedAt: Date?
    let betaCount: Int?

    enum CodingKeys: String, CodingKey {
        case id, colour, terrain, styles, lifecycle
        case gymID = "gym_id"
        case wallZoneID = "wall_zone_id"
        case subjectiveGrade = "subjective_grade"
        case gymGrade = "gym_grade"
        case setDate = "set_date"
        case estimatedArchiveDate = "estimated_archive_date"
        case isArchiveDateEstimated = "is_archive_date_estimated"
        case archivedAt = "archived_at"
        case betaCount = "beta_count"
    }

    func domain(
        communityGrade: CommunityGradeRecord,
        photoReference: RoutePhotoReference? = nil
    ) throws -> ClimbingRoute {
        guard communityGrade.routeID == id else {
            throw RemoteMappingError.inconsistentData("Community grade belongs to a different route.")
        }
        let colourValue = colour?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let colourValue, !colourValue.isEmpty else {
            throw RemoteMappingError.inconsistentData("A route requires a colour.")
        }

        let domainLifecycle: RouteLifecycle
        switch lifecycle {
        case "active": domainLifecycle = .active
        case "temporarily_hidden": domainLifecycle = .temporarilyHidden
        case "archived": domainLifecycle = .archived
        default: throw RemoteMappingError.unsupportedValue(field: "routes.lifecycle", value: lifecycle)
        }

        if domainLifecycle == .archived, archivedAt == nil {
            throw RemoteMappingError.inconsistentData("An archived route requires archived_at.")
        }
        if isArchiveDateEstimated, estimatedArchiveDate == nil {
            throw RemoteMappingError.inconsistentData("An estimated archive flag requires a date.")
        }

        let domainTerrain: RouteTerrain
        switch terrain {
        case "slab", nil: domainTerrain = .slab
        case "vertical": domainTerrain = .vertical
        case "overhang": domainTerrain = .overhang
        case "roof": domainTerrain = .roof
        case "cave": domainTerrain = .cave
        case "mixed": domainTerrain = .mixed
        default: throw RemoteMappingError.unsupportedValue(field: "routes.terrain", value: terrain ?? "")
        }

        let domainStyles: [RouteStyle] = try (styles ?? []).map { raw in
            guard let style = RouteStyle(rawValue: raw) else {
                throw RemoteMappingError.unsupportedValue(field: "routes.styles", value: raw)
            }
            return style
        }

        return ClimbingRoute(
            id: ClimbingRouteID(rawValue: RemoteIdentifier.domainString(id)),
            gymID: GymID(rawValue: RemoteIdentifier.domainString(gymID)),
            wallZoneID: WallZoneID(rawValue: RemoteIdentifier.domainString(wallZoneID)),
            colour: colourValue,
            terrain: domainTerrain,
            styles: domainStyles,
            subjectiveGrade: try RemoteGrade.domain(subjectiveGrade, field: "routes.subjective_grade"),
            officialGrade: try RemoteGrade.domain(gymGrade, field: "routes.gym_grade"),
            communityGradeSummary: try communityGrade.domain(),
            resetDate: setDate,
            expectedArchiveDate: estimatedArchiveDate,
            isArchiveDateEstimated: isArchiveDateEstimated,
            lifecycle: domainLifecycle,
            photoReference: photoReference,
            betaCount: max(0, betaCount ?? 0)
        )
    }
}

nonisolated struct CommunityGradeRecord: Codable, Equatable, Sendable {
    let routeID: UUID
    let voteCount: Int
    let isDisplayEligible: Bool
    let medianVGrade: Int?

    enum CodingKeys: String, CodingKey {
        case routeID = "route_id"
        case voteCount = "vote_count"
        case isDisplayEligible = "is_display_eligible"
        case medianVGrade = "median_v_grade"
    }

    func domain() throws -> CommunityGradeSummary {
        guard voteCount >= 0 else {
            throw RemoteMappingError.inconsistentData("Community vote count cannot be negative.")
        }
        if voteCount < 3 {
            guard !isDisplayEligible, medianVGrade == nil else {
                throw RemoteMappingError.inconsistentData(
                    "Community median must be hidden below three votes."
                )
            }
            return CommunityGradeSummary(voteCount: voteCount, medianGrade: nil)
        }

        guard isDisplayEligible,
              let median = try RemoteGrade.domain(
                medianVGrade,
                field: "community_grade_summary.median_v_grade"
              ) else {
            throw RemoteMappingError.inconsistentData(
                "An eligible community grade requires a valid median."
            )
        }
        return CommunityGradeSummary(voteCount: voteCount, medianGrade: median)
    }
}
