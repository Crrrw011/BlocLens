import Foundation
import Supabase

nonisolated protocol RemoteLogbookDataSource: Sendable {
    func currentUserID() -> UUID?
    func fetchEntries(userID: UUID) async throws -> [LogbookEntryRecord]
    func upsertEntry(_ write: LogbookEntryWrite) async throws
    func softDeleteEntry(entryID: UUID) async throws
    func hasAttemptedRoute(routeID: UUID) async throws -> Bool
}

nonisolated struct LogbookEntryWrite: Encodable, Sendable {
    let userID: String
    let routeID: String
    let status: String
    let climbedAt: String
    let attempts: Int?
    let privateNote: String?
    let predictedVGrade: Int?
    let clientCreatedAt: String
    let clientIdempotencyKey: String

    enum CodingKeys: String, CodingKey {
        case status, attempts
        case userID = "user_id"
        case routeID = "route_id"
        case climbedAt = "climbed_at"
        case privateNote = "private_note"
        case predictedVGrade = "predicted_v_grade"
        case clientCreatedAt = "client_created_at"
        case clientIdempotencyKey = "client_idempotency_key"
    }
}

struct SupabaseLogbookDataSource: RemoteLogbookDataSource, Sendable {
    let client: SupabaseClient

    func currentUserID() -> UUID? {
        client.auth.currentUser?.id
    }

    func fetchEntries(userID: UUID) async throws -> [LogbookEntryRecord] {
        let response: PostgrestResponse<[LogbookEntryRecord]> = try await client
            .from("logbook_entries")
            .select()
            .eq("user_id", value: userID.uuidString)
            .is("deleted_at", value: nil)
            .execute()
        return response.value
    }

    func upsertEntry(_ write: LogbookEntryWrite) async throws {
        _ = try await client
            .from("logbook_entries")
            .upsert(write, onConflict: "user_id,route_id", returning: .minimal)
            .execute()
    }

    func softDeleteEntry(entryID: UUID) async throws {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestamp = formatter.string(from: Date())
        _ = try await client
            .from("logbook_entries")
            .update(["deleted_at": AnyJSON.string(timestamp)], returning: .minimal)
            .eq("id", value: entryID.uuidString)
            .execute()
    }

    func hasAttemptedRoute(routeID: UUID) async throws -> Bool {
        let response: PostgrestResponse<Bool> = try await client
            .rpc("has_attempted_route", params: ["requested_route_id": routeID.uuidString])
            .execute()
        return response.value
    }
}
