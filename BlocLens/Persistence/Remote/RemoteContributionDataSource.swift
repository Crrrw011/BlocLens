import Foundation
import Supabase

nonisolated protocol RemoteContributionDataSource: Sendable {
    func currentUserID() -> UUID?
    func isGymOfficial(gymID: UUID) async throws -> Bool
    func insertRoute(_ write: RouteContributionWrite) async throws -> RouteRecord
    func fetchRoute(id: UUID) async throws -> RouteRecord
    func updateRoute(id: UUID, write: RouteUpdateWrite) async throws -> RouteRecord
    func insertWallZone(_ write: WallZoneContributionWrite) async throws -> WallZoneRecord
    func fetchWallZone(id: UUID) async throws -> WallZoneRecord
    func updateWallZone(id: UUID, write: WallZoneUpdateWrite) async throws -> WallZoneRecord
    func insertBetaLink(_ write: BetaContributionWrite) async throws -> BetaLinkRecord
    func fetchBetaLink(id: UUID) async throws -> BetaLinkRecord
    func insertPhoto(_ write: RoutePhotoContributionWrite) async throws -> RoutePhotoRecord
    func fetchPhoto(id: UUID) async throws -> RoutePhotoRecord
    func insertCorrection(_ write: RouteCorrectionWrite) async throws -> RouteCorrectionRecord
    func fetchCorrection(id: UUID) async throws -> RouteCorrectionRecord
    func insertResetEvent(_ write: ResetEventWrite) async throws
    func insertResetConfirmation(eventID: UUID, userID: UUID) async throws
    func fetchResetEvent(id: UUID) async throws -> ResetEventRecord?
    func fetchBlockedUserIDs(userID: UUID) async throws -> [UUID]
    func fetchComments(betaLinkID: UUID) async throws -> [BetaCommentRecord]
    func insertComment(_ write: BetaCommentWrite) async throws -> BetaCommentRecord
    func fetchComment(id: UUID) async throws -> BetaCommentRecord
    func insertReport(_ write: ContentReportWrite) async throws -> ContentReportRecord
    func fetchReport(id: UUID) async throws -> ContentReportRecord
    func insertFeedback(_ write: FeedbackWrite) async throws -> FeedbackRecord
    func fetchFeedback(id: UUID) async throws -> FeedbackRecord
    func insertGymSubmission(_ write: GymSubmissionWrite) async throws -> GymSubmissionRecord
    func fetchGymSubmission(id: UUID) async throws -> GymSubmissionRecord
}

nonisolated struct RouteContributionWrite: Encodable, Sendable {
    let id: String
    let gymID: String
    let wallZoneID: String
    let colour: String
    let terrain: String
    let styles: [String]
    let subjectiveGrade: Int?
    let setDate: String?
    let createdBy: String
    let isOfficialSource: Bool

    enum CodingKeys: String, CodingKey {
        case id, colour, terrain, styles
        case gymID = "gym_id"
        case wallZoneID = "wall_zone_id"
        case subjectiveGrade = "subjective_grade"
        case setDate = "set_date"
        case createdBy = "created_by"
        case isOfficialSource = "is_official_source"
    }
}

nonisolated struct RouteUpdateWrite: Encodable, Sendable {
    let colour: String
    let terrain: String
    let styles: [String]
    let subjectiveGrade: Int?

    enum CodingKeys: String, CodingKey {
        case colour, terrain, styles
        case subjectiveGrade = "subjective_grade"
    }
}

nonisolated struct WallZoneContributionWrite: Encodable, Sendable {
    let id: String
    let gymID: String
    let name: String
    let locationDescription: String?
    let wallKind: String
    let surfaceMaterial: String
    let surfaceTexture: String
    let hasBoltHoles: Bool
    let displayOrder: Int
    let createdBy: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case gymID = "gym_id"
        case locationDescription = "location_description"
        case wallKind = "wall_kind"
        case surfaceMaterial = "surface_material"
        case surfaceTexture = "surface_texture"
        case hasBoltHoles = "has_bolt_holes"
        case displayOrder = "display_order"
        case createdBy = "created_by"
    }
}

nonisolated struct WallZoneUpdateWrite: Encodable, Sendable {
    let name: String
    let locationDescription: String?
    let wallKind: String
    let surfaceMaterial: String
    let surfaceTexture: String
    let hasBoltHoles: Bool
    let displayOrder: Int

    enum CodingKeys: String, CodingKey {
        case name
        case locationDescription = "location_description"
        case wallKind = "wall_kind"
        case surfaceMaterial = "surface_material"
        case surfaceTexture = "surface_texture"
        case hasBoltHoles = "has_bolt_holes"
        case displayOrder = "display_order"
    }
}

nonisolated struct BetaContributionWrite: Encodable, Sendable {
    let id: String
    let routeID: String
    let publicURL: String
    let platform: String
    let originalAuthorDisplayName: String
    let originalPostURL: String
    let submittedBy: String
    let tags: [String]
    let submitterHeightCM: Double?
    let submitterArmSpanCM: Double?
    let embedCapability: String
    let isOfficialSource: Bool
    enum CodingKeys: String, CodingKey {
        case id, platform, tags
        case routeID = "route_id"
        case publicURL = "public_url"
        case originalAuthorDisplayName = "original_author_display_name"
        case originalPostURL = "original_post_url"
        case submittedBy = "submitted_by"
        case submitterHeightCM = "submitter_height_cm"
        case submitterArmSpanCM = "submitter_arm_span_cm"
        case embedCapability = "embed_capability"
        case isOfficialSource = "is_official_source"
    }
}

nonisolated struct RoutePhotoContributionWrite: Encodable, Sendable {
    let id: String
    let routeID: String
    let storagePath: String
    let uploadedBy: String
    let isOfficialSource: Bool
    let width: Int?
    let height: Int?

    enum CodingKeys: String, CodingKey {
        case id, width, height
        case routeID = "route_id"
        case storagePath = "storage_path"
        case uploadedBy = "uploaded_by"
        case isOfficialSource = "is_official_source"
    }
}

nonisolated struct RouteCorrectionWrite: Encodable, Sendable {
    let id: String
    let routeID: String
    let submittedBy: String
    let issueKey: String
    let proposedValue: String?
    let explanation: String?

    enum CodingKeys: String, CodingKey {
        case id, explanation
        case routeID = "route_id"
        case submittedBy = "submitted_by"
        case issueKey = "issue_key"
        case proposedValue = "proposed_value"
    }
}

nonisolated struct ResetEventWrite: Encodable, Sendable {
    let id: String
    let gymID: String
    let wallZoneID: String
    let resetDate: String
    let source: String
    let state: String
    let createdBy: String
    let isOfficial: Bool

    enum CodingKeys: String, CodingKey {
        case id, source, state
        case gymID = "gym_id"
        case wallZoneID = "wall_zone_id"
        case resetDate = "reset_date"
        case createdBy = "created_by"
        case isOfficial = "is_official"
    }
}

nonisolated struct BetaCommentWrite: Encodable, Sendable {
    let id: String
    let betaLinkID: String
    let authorID: String
    let officialGymID: String?
    let body: String

    enum CodingKeys: String, CodingKey {
        case id, body
        case betaLinkID = "beta_link_id"
        case authorID = "author_id"
        case officialGymID = "official_gym_id"
    }
}

nonisolated struct ContentReportWrite: Encodable, Sendable {
    let id: String
    let targetType: String
    let targetID: String
    let category: String
    let reporterID: String
    let details: String?

    enum CodingKeys: String, CodingKey {
        case id, category, details
        case targetType = "target_type"
        case targetID = "target_id"
        case reporterID = "reporter_id"
    }
}

nonisolated struct FeedbackWrite: Encodable, Sendable {
    let id: String
    let userID: String?
    let category: String
    let message: String
    let currentPageID: String?

    enum CodingKeys: String, CodingKey {
        case id, category, message
        case userID = "user_id"
        case currentPageID = "current_page_id"
    }
}

nonisolated struct GymSubmissionWrite: Encodable, Sendable {
    let id: String
    let googlePlaceID: String
    let name: String
    let streetAddress: String?
    let suburb: String
    let state: String
    let postcode: String?
    let latitude: Double
    let longitude: Double
    let submittedBy: String

    enum CodingKeys: String, CodingKey {
        case id, name, latitude, longitude
        case googlePlaceID = "google_place_id"
        case streetAddress = "street_address"
        case suburb, state, postcode
        case submittedBy = "submitted_by"
    }
}

struct SupabaseContributionDataSource: RemoteContributionDataSource, Sendable {
    let client: SupabaseClient

    func currentUserID() -> UUID? { client.auth.currentUser?.id }

    func isGymOfficial(gymID: UUID) async throws -> Bool {
        let response: PostgrestResponse<Bool> = try await client
            .rpc("is_gym_official", params: ["requested_gym_id": gymID.uuidString])
            .execute()
        return response.value
    }

    func insertRoute(_ write: RouteContributionWrite) async throws -> RouteRecord {
        try await insert(write, into: "routes")
    }

    func updateRoute(id: UUID, write: RouteUpdateWrite) async throws -> RouteRecord {
        let response: PostgrestResponse<RouteRecord> = try await client
            .from("routes")
            .update(write)
            .eq("id", value: id.uuidString)
            .select()
            .single()
            .execute()
        return response.value
    }

    func fetchRoute(id: UUID) async throws -> RouteRecord { try await fetch(id, from: "routes") }

    func insertWallZone(_ write: WallZoneContributionWrite) async throws -> WallZoneRecord {
        try await insert(write, into: "wall_zones")
    }

    func updateWallZone(id: UUID, write: WallZoneUpdateWrite) async throws -> WallZoneRecord {
        let response: PostgrestResponse<WallZoneRecord> = try await client
            .from("wall_zones")
            .update(write)
            .eq("id", value: id.uuidString)
            .select()
            .single()
            .execute()
        return response.value
    }

    func fetchWallZone(id: UUID) async throws -> WallZoneRecord {
        let response: PostgrestResponse<WallZoneRecord> = try await client
            .from("wall_zone_summaries")
            .select()
            .eq("id", value: id.uuidString)
            .single()
            .execute()
        return response.value
    }

    func insertBetaLink(_ write: BetaContributionWrite) async throws -> BetaLinkRecord {
        try await insert(write, into: "beta_links")
    }

    func fetchBetaLink(id: UUID) async throws -> BetaLinkRecord { try await fetch(id, from: "beta_links") }

    func insertPhoto(_ write: RoutePhotoContributionWrite) async throws -> RoutePhotoRecord {
        try await insert(write, into: "route_photos")
    }

    func fetchPhoto(id: UUID) async throws -> RoutePhotoRecord { try await fetch(id, from: "route_photos") }

    func insertCorrection(_ write: RouteCorrectionWrite) async throws -> RouteCorrectionRecord {
        try await insert(write, into: "route_corrections")
    }

    func fetchCorrection(id: UUID) async throws -> RouteCorrectionRecord {
        try await fetch(id, from: "route_corrections")
    }

    func insertResetEvent(_ write: ResetEventWrite) async throws {
        _ = try await client.from("reset_events").insert(write, returning: .minimal).execute()
    }

    func insertResetConfirmation(eventID: UUID, userID: UUID) async throws {
        _ = try await client.from("reset_confirmations").insert(
            ["reset_event_id": eventID.uuidString, "user_id": userID.uuidString],
            returning: .minimal
        ).execute()
    }

    func fetchResetEvent(id: UUID) async throws -> ResetEventRecord? {
        let response: PostgrestResponse<[ResetEventRecord]> = try await client
            .from("reset_events").select("id,state,confirmation_count,is_official")
            .eq("id", value: id.uuidString).execute()
        return response.value.first
    }

    func fetchBlockedUserIDs(userID: UUID) async throws -> [UUID] {
        let response: PostgrestResponse<[BlockedIDRecordForContribution]> = try await client
            .from("user_blocks").select("blocked_id")
            .eq("blocker_id", value: userID.uuidString).execute()
        return response.value.map(\.blockedID)
    }

    func fetchComments(betaLinkID: UUID) async throws -> [BetaCommentRecord] {
        let response: PostgrestResponse<[BetaCommentRecord]> = try await client
            .from("beta_comments").select()
            .eq("beta_link_id", value: betaLinkID.uuidString)
            .order("created_at", ascending: true).execute()
        return response.value
    }

    func insertComment(_ write: BetaCommentWrite) async throws -> BetaCommentRecord {
        try await insert(write, into: "beta_comments")
    }

    func fetchComment(id: UUID) async throws -> BetaCommentRecord { try await fetch(id, from: "beta_comments") }

    func insertReport(_ write: ContentReportWrite) async throws -> ContentReportRecord {
        try await insert(write, into: "content_reports")
    }

    func fetchReport(id: UUID) async throws -> ContentReportRecord { try await fetch(id, from: "content_reports") }

    func insertFeedback(_ write: FeedbackWrite) async throws -> FeedbackRecord {
        try await insert(write, into: "app_feedback")
    }

    func fetchFeedback(id: UUID) async throws -> FeedbackRecord { try await fetch(id, from: "app_feedback") }

    func insertGymSubmission(_ write: GymSubmissionWrite) async throws -> GymSubmissionRecord {
        try await insert(write, into: "gym_submissions")
    }

    func fetchGymSubmission(id: UUID) async throws -> GymSubmissionRecord { try await fetch(id, from: "gym_submissions") }

    private func insert<Write: Encodable & Sendable, Record: Decodable & Sendable>(
        _ write: Write,
        into table: String
    ) async throws -> Record {
        let response: PostgrestResponse<Record> = try await client
            .from(table).insert(write).select().single().execute()
        return response.value
    }

    private func fetch<Record: Decodable & Sendable>(_ id: UUID, from table: String) async throws -> Record {
        let response: PostgrestResponse<Record> = try await client
            .from(table).select().eq("id", value: id.uuidString).single().execute()
        return response.value
    }
}

private struct BlockedIDRecordForContribution: Decodable {
    let blockedID: UUID
    enum CodingKeys: String, CodingKey { case blockedID = "blocked_id" }
}
