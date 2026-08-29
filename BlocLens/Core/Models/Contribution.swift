import Foundation

nonisolated struct IdempotencyKey: RawRepresentable, Codable, Equatable, Hashable, Sendable {
    let rawValue: UUID

    init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

nonisolated struct AddRouteRequest: Equatable, Sendable {
    let idempotencyKey: IdempotencyKey
    let gymID: GymID
    let wallZoneID: WallZoneID
    let colour: String
    let terrain: RouteTerrain
    let styles: [RouteStyle]
    let subjectiveGrade: VGrade?
    let setDate: Date?
}

nonisolated struct AddWallZoneRequest: Equatable, Sendable {
    let idempotencyKey: IdempotencyKey
    let gymID: GymID
    let name: String
    let locationDescription: String?
    let wallKind: WallKind
    let surfaceMaterial: SurfaceMaterial
    let surfaceTexture: SurfaceTexture
    let hasBoltHoles: Bool
    let sortOrder: Int
}

nonisolated struct ShareBetaLinkRequest: Equatable, Sendable {
    let idempotencyKey: IdempotencyKey
    let routeID: ClimbingRouteID
    let publicURL: URL
    let platform: BetaPlatform
    let originalAuthor: String
    let originalPostURL: URL
    let tags: [BetaTag]
    let contributorHeightCentimetres: Double?
    let contributorArmSpanCentimetres: Double?
    let embedSupport: BetaEmbedSupport
}

nonisolated struct AddRoutePhotoRequest: Equatable, Sendable {
    let idempotencyKey: IdempotencyKey
    let routeID: ClimbingRouteID
    let publicImageURL: URL
    let width: Int?
    let height: Int?
}

nonisolated struct RoutePhotoMetadata: Identifiable, Equatable, Sendable {
    let id: UUID
    let routeID: ClimbingRouteID
    let publicImageURL: URL
    let contributorID: UserID
    let isOfficialSource: Bool
    let createdAt: Date
}

nonisolated enum RouteCorrectionIssue: String, CaseIterable, Codable, Sendable {
    case colour
    case label
    case grade
    case resetDate = "reset_date"
    case routeStatus = "route_status"
    case photo
    case other
}

nonisolated struct SubmitRouteCorrectionRequest: Equatable, Sendable {
    let idempotencyKey: IdempotencyKey
    let routeID: ClimbingRouteID
    let issue: RouteCorrectionIssue
    let proposedValue: String?
    let explanation: String?
}

nonisolated struct RouteCorrectionReceipt: Identifiable, Equatable, Sendable {
    let id: UUID
    let routeID: ClimbingRouteID
    let issue: RouteCorrectionIssue
    let status: String
}

nonisolated struct ConfirmResetRequest: Equatable, Sendable {
    let idempotencyKey: IdempotencyKey
    let gymID: GymID
    let wallZoneID: WallZoneID
    let resetDate: Date
}

nonisolated enum ResetConfirmationState: String, Equatable, Sendable {
    case pending
    case confirmed
}

nonisolated struct ResetConfirmationReceipt: Equatable, Sendable {
    let resetEventID: UUID
    let state: ResetConfirmationState
    let confirmationCount: Int
    let isOfficial: Bool
}

nonisolated struct BetaComment: Identifiable, Equatable, Sendable {
    let id: UUID
    let betaLinkID: BetaLinkID
    let authorID: UserID
    let officialGymID: GymID?
    let body: String
    let createdAt: Date
}

nonisolated struct AddBetaCommentRequest: Equatable, Sendable {
    let idempotencyKey: IdempotencyKey
    let betaLinkID: BetaLinkID
    let body: String
    let officialGymID: GymID?
}

nonisolated enum ReportableContentType: String, Codable, Sendable {
    case route
    case betaLink = "beta_link"
    case betaComment = "beta_comment"
    case routePhoto = "route_photo"
    case wallZone = "wall_zone"
}

nonisolated enum ContentReportCategory: String, CaseIterable, Codable, Sendable {
    case wrongRoute = "wrong_route"
    case brokenLink = "broken_link"
    case unsafeContent = "unsafe_content"
    case nudity
    case harassment
    case violence
    case minorPrivacy = "minor_privacy"
    case spam
    case other

    var isSevere: Bool {
        switch self {
        case .nudity, .harassment, .violence, .minorPrivacy: true
        default: false
        }
    }
}

nonisolated struct SubmitContentReportRequest: Equatable, Sendable {
    let idempotencyKey: IdempotencyKey
    let targetType: ReportableContentType
    let targetID: String
    let category: ContentReportCategory
    let details: String?
}

nonisolated struct ContentReportReceipt: Identifiable, Equatable, Sendable {
    let id: UUID
    let targetType: ReportableContentType
    let targetID: String
    let category: ContentReportCategory
    let isSevere: Bool
}

nonisolated enum FeedbackCategory: String, CaseIterable, Codable, Sendable {
    case issue
    case suggestion
    case safety
    case dataCorrection = "data_correction"
    case other
}

nonisolated struct SubmitFeedbackRequest: Equatable, Sendable {
    let idempotencyKey: IdempotencyKey
    let category: FeedbackCategory
    let message: String
    let currentPageID: String?
}

nonisolated struct FeedbackReceipt: Identifiable, Equatable, Sendable {
    let id: UUID
    let category: FeedbackCategory
}

nonisolated struct SubmitGymRequest: Equatable, Sendable {
    let idempotencyKey: IdempotencyKey
    let googlePlaceID: String
    let name: String
    let streetAddress: String?
    let suburb: String
    let state: String
    let postcode: String?
    let latitude: Double
    let longitude: Double
}

nonisolated struct GymSubmissionReceipt: Identifiable, Equatable, Sendable {
    let id: UUID
    let status: String
}
