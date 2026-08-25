import Foundation
import Supabase

nonisolated protocol RemoteBetaDataSource: Sendable {
    func currentUserID() -> UUID?
    func hasConfirmedSafety() -> Bool
    func confirmSafety() async throws
    func fetchBlockedUserIDs(blockerID: UUID) async throws -> [UUID]
    func fetchBetaLinks(routeID: UUID) async throws -> [BetaLinkRecord]
    func fetchBetaLink(betaID: UUID) async throws -> BetaLinkRecord
    func insertHelpfulVote(betaID: UUID, userID: UUID) async throws
    func insertReport(betaID: UUID, reporterID: UUID, category: String) async throws
    func hasValidAttempt(routeID: UUID) async throws -> Bool
    func insertGradeVote(routeID: UUID, userID: UUID, grade: Int) async throws
    func updateGradeVote(routeID: UUID, userID: UUID, grade: Int) async throws
    func fetchMyGradeVote(routeID: UUID, userID: UUID) async throws -> Int?
}

struct SupabaseBetaDataSource: RemoteBetaDataSource, Sendable {
    let client: SupabaseClient

    func currentUserID() -> UUID? {
        client.auth.currentUser?.id
    }

    func hasConfirmedSafety() -> Bool {
        client.auth.currentUser?.userMetadata["beta_safety_confirmed_at"] != nil
    }

    func confirmSafety() async throws {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestamp = formatter.string(from: Date())
        _ = try await client.auth.update(
            user: UserAttributes(data: ["beta_safety_confirmed_at": AnyJSON.string(timestamp)])
        )
    }

    func fetchBlockedUserIDs(blockerID: UUID) async throws -> [UUID] {
        let response: PostgrestResponse<[BlockedIDRecord]> = try await client
            .from("user_blocks")
            .select("blocked_id")
            .eq("blocker_id", value: blockerID.uuidString)
            .execute()
        return response.value.map(\.blockedID)
    }

    func fetchBetaLinks(routeID: UUID) async throws -> [BetaLinkRecord] {
        let response: PostgrestResponse<[BetaLinkRecord]> = try await client
            .from("beta_links")
            .select()
            .eq("route_id", value: routeID.uuidString)
            .execute()
        return response.value
    }

    func fetchBetaLink(betaID: UUID) async throws -> BetaLinkRecord {
        let response: PostgrestResponse<BetaLinkRecord> = try await client
            .from("beta_links")
            .select()
            .eq("id", value: betaID.uuidString)
            .single()
            .execute()
        return response.value
    }

    func insertHelpfulVote(betaID: UUID, userID: UUID) async throws {
        _ = try await client
            .from("beta_helpful_votes")
            .insert(["beta_link_id": betaID.uuidString, "user_id": userID.uuidString], returning: .minimal)
            .execute()
    }

    func insertReport(betaID: UUID, reporterID: UUID, category: String) async throws {
        _ = try await client
            .from("content_reports")
            .insert([
                "target_type": "beta_link",
                "target_id": betaID.uuidString,
                "category": category,
                "reporter_id": reporterID.uuidString
            ], returning: .minimal)
            .execute()
    }

    func hasValidAttempt(routeID: UUID) async throws -> Bool {
        let response: PostgrestResponse<Bool> = try await client
            .rpc("has_attempted_route", params: ["requested_route_id": routeID.uuidString])
            .execute()
        return response.value
    }

    func insertGradeVote(routeID: UUID, userID: UUID, grade: Int) async throws {
        _ = try await client
            .from("route_grade_votes")
            .insert(
                [
                    "route_id": AnyJSON.string(routeID.uuidString),
                    "user_id": AnyJSON.string(userID.uuidString),
                    "v_grade": AnyJSON.integer(grade)
                ],
                returning: .minimal
            )
            .execute()
    }

    func updateGradeVote(routeID: UUID, userID: UUID, grade: Int) async throws {
        _ = try await client
            .from("route_grade_votes")
            .update(["v_grade": AnyJSON.integer(grade)], returning: .minimal)
            .eq("route_id", value: routeID.uuidString)
            .eq("user_id", value: userID.uuidString)
            .execute()
    }

    func fetchMyGradeVote(routeID: UUID, userID: UUID) async throws -> Int? {
        let response: PostgrestResponse<[GradeVoteRecord]> = try await client
            .from("route_grade_votes")
            .select("v_grade")
            .eq("route_id", value: routeID.uuidString)
            .eq("user_id", value: userID.uuidString)
            .execute()
        return response.value.first?.vGrade
    }
}

private struct BlockedIDRecord: Decodable {
    let blockedID: UUID

    enum CodingKeys: String, CodingKey {
        case blockedID = "blocked_id"
    }
}

private struct GradeVoteRecord: Decodable {
    let vGrade: Int

    enum CodingKeys: String, CodingKey {
        case vGrade = "v_grade"
    }
}
