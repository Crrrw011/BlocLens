import Foundation

nonisolated struct BetaLinkRecord: Codable, Equatable, Sendable {
    let id: UUID
    let routeID: UUID
    let publicURL: String
    let platform: String
    let originalAuthorDisplayName: String
    let originalPostURL: String
    let tags: [String]
    let helpfulCount: Int
    let submitterHeightCM: Double?
    let submitterArmSpanCM: Double?
    let linkStatus: String
    let moderationStatus: String
    let embedCapability: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, platform, tags
        case routeID = "route_id"
        case publicURL = "public_url"
        case originalAuthorDisplayName = "original_author_display_name"
        case originalPostURL = "original_post_url"
        case helpfulCount = "helpful_count"
        case submitterHeightCM = "submitter_height_cm"
        case submitterArmSpanCM = "submitter_arm_span_cm"
        case linkStatus = "link_status"
        case moderationStatus = "moderation_status"
        case embedCapability = "embed_capability"
        case createdAt = "created_at"
    }

    func domain() throws -> BetaLink {
        guard let sourceURL = URL(string: publicURL), BetaLink.isValidExternalURL(sourceURL) else {
            throw RemoteMappingError.invalidURL(field: "beta_links.public_url", value: publicURL)
        }
        guard sourceURL.scheme?.lowercased() == "https" else {
            throw RemoteMappingError.invalidURL(field: "beta_links.public_url", value: publicURL)
        }
        guard let postURL = URL(string: originalPostURL), BetaLink.isValidExternalURL(postURL),
              postURL.scheme?.lowercased() == "https" else {
            throw RemoteMappingError.invalidURL(
                field: "beta_links.original_post_url",
                value: originalPostURL
            )
        }

        let domainPlatform: BetaPlatform
        switch platform {
        case "youtube": domainPlatform = .youtube
        case "instagram": domainPlatform = .instagram
        case "tiktok": domainPlatform = .tiktok
        case "vimeo": domainPlatform = .vimeo
        case "other": domainPlatform = .other
        default: throw RemoteMappingError.unsupportedValue(field: "beta_links.platform", value: platform)
        }

        let domainTags = try tags.map { value -> BetaTag in
            switch value {
            case "full_solution": .fullSolution
            case "crux": .crux
            case "static": .staticMovement
            case "dynamic": .dynamicMovement
            case "short_climber": .shortPersonBeta
            case "tall_climber": .tallLongReachBeta
            default: throw RemoteMappingError.unsupportedValue(field: "beta_links.tags", value: value)
            }
        }

        let health: BetaLinkHealth
        switch linkStatus {
        case "healthy": health = .healthy
        case "broken", "removed_by_source": health = .broken
        default:
            throw RemoteMappingError.unsupportedValue(field: "beta_links.link_status", value: linkStatus)
        }

        let moderation: BetaModerationState
        switch moderationStatus {
        case "visible": moderation = .visible
        case "temporarily_hidden", "removed": moderation = .temporarilyHidden
        default:
            throw RemoteMappingError.unsupportedValue(
                field: "beta_links.moderation_status",
                value: moderationStatus
            )
        }

        let embed: BetaEmbedSupport
        switch embedCapability {
        case "supported": embed = .supported
        case "source_platform_only": embed = .sourcePlatformOnly
        default:
            throw RemoteMappingError.unsupportedValue(
                field: "beta_links.embed_capability",
                value: embedCapability
            )
        }

        return BetaLink(
            id: BetaLinkID(rawValue: RemoteIdentifier.domainString(id)),
            routeID: ClimbingRouteID(rawValue: RemoteIdentifier.domainString(routeID)),
            sourceURL: sourceURL,
            platform: domainPlatform,
            originalAuthor: originalAuthorDisplayName,
            originalPostURL: postURL,
            tags: domainTags,
            helpfulCount: max(0, helpfulCount),
            contributorHeightCentimetres: submitterHeightCM,
            contributorArmSpanCentimetres: submitterArmSpanCM,
            linkHealth: health,
            moderationState: moderation,
            embedSupport: embed,
            createdDate: createdAt
        )
    }
}
