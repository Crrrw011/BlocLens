import Foundation

nonisolated enum BetaPlatform: String, CaseIterable, Codable, Equatable, Sendable {
    case youtube
    case instagram
    case tiktok
    case vimeo
    case other
}

nonisolated enum BetaTag: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case fullSolution
    case crux
    case staticMovement
    case dynamicMovement
    case shortPersonBeta
    case tallLongReachBeta
}

nonisolated enum BetaLinkHealth: String, Codable, Equatable, Sendable {
    case healthy
    case broken
}

nonisolated enum BetaModerationState: String, Codable, Equatable, Sendable {
    case visible
    case temporarilyHidden
}

nonisolated enum BetaEmbedSupport: String, Codable, Equatable, Sendable {
    case supported
    case sourcePlatformOnly
}

nonisolated struct BetaLink: Identifiable, Codable, Equatable, Hashable, Sendable {
    let id: BetaLinkID
    let routeID: ClimbingRouteID
    let sourceURL: URL
    let platform: BetaPlatform
    let originalAuthor: String
    let originalPostURL: URL
    let tags: [BetaTag]
    let helpfulCount: Int
    let contributorHeightCentimetres: Double?
    let contributorArmSpanCentimetres: Double?
    let linkHealth: BetaLinkHealth
    let moderationState: BetaModerationState
    let embedSupport: BetaEmbedSupport
    let createdDate: Date

    static func isValidExternalURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host != nil else {
            return false
        }
        return true
    }
}

nonisolated struct BetaViewerProfile: Equatable, Sendable {
    let heightCentimetres: Double?
    let armSpanCentimetres: Double?
}

nonisolated enum ReportReason: String, CaseIterable, Sendable {
    case brokenLink
    case wrongRoute
    case unsafeContent

    var databaseValue: String {
        switch self {
        case .brokenLink: "broken_link"
        case .wrongRoute: "wrong_route"
        case .unsafeContent: "unsafe_content"
        }
    }
}
