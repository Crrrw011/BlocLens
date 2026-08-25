import Foundation
import Supabase

nonisolated protocol RemoteGymDataSource: Sendable {
    func fetchGymSummaries() async throws -> [GymRecord]
    func fetchGymSummary(id: UUID) async throws -> GymRecord
    func fetchFacilities() async throws -> [GymFacilityRecord]
    func fetchWallZoneSummaries() async throws -> [WallZoneRecord]
    func fetchHardSoftBands(gymID: UUID) async throws -> [GymHardSoftBandRecord]
}

nonisolated protocol RemoteRouteDataSource: Sendable {
    func fetchRouteSummaries() async throws -> [RouteRecord]
    func fetchRouteSummary(id: UUID) async throws -> RouteRecord
    func fetchCommunityGrade(routeID: UUID) async throws -> CommunityGradeRecord?
}

struct SupabaseRemoteDataSource: RemoteGymDataSource, RemoteRouteDataSource, Sendable {
    let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func fetchGymSummaries() async throws -> [GymRecord] {
        try await execute {
            let response: PostgrestResponse<[GymRecord]> = try await client
                .from("gym_summaries")
                .select()
                .execute()
            return response.value
        }
    }

    func fetchGymSummary(id: UUID) async throws -> GymRecord {
        try await execute {
            let response: PostgrestResponse<GymRecord> = try await client
                .from("gym_summaries")
                .select()
                .eq("id", value: id.uuidString)
                .single()
                .execute()
            return response.value
        }
    }

    func fetchFacilities() async throws -> [GymFacilityRecord] {
        try await execute {
            let response: PostgrestResponse<[GymFacilityRecord]> = try await client
                .from("gym_facilities")
                .select()
                .execute()
            return response.value
        }
    }

    func fetchWallZoneSummaries() async throws -> [WallZoneRecord] {
        try await execute {
            let response: PostgrestResponse<[WallZoneRecord]> = try await client
                .from("wall_zone_summaries")
                .select()
                .execute()
            return response.value
        }
    }

    func fetchHardSoftBands(gymID: UUID) async throws -> [GymHardSoftBandRecord] {
        try await execute {
            let response: PostgrestResponse<[GymHardSoftBandRecord]> = try await client
                .rpc("gym_hard_soft_summary", params: ["requested_gym_id": gymID.uuidString])
                .execute()
            return response.value
        }
    }

    func fetchRouteSummaries() async throws -> [RouteRecord] {
        try await execute {
            let response: PostgrestResponse<[RouteRecord]> = try await client
                .from("route_summaries")
                .select()
                .execute()
            return response.value
        }
    }

    func fetchRouteSummary(id: UUID) async throws -> RouteRecord {
        try await execute {
            let response: PostgrestResponse<RouteRecord> = try await client
                .from("route_summaries")
                .select()
                .eq("id", value: id.uuidString)
                .single()
                .execute()
            return response.value
        }
    }

    func fetchCommunityGrade(routeID: UUID) async throws -> CommunityGradeRecord? {
        try await execute {
            let response: PostgrestResponse<[CommunityGradeRecord]> = try await client
                .rpc("community_grade_summary", params: ["requested_route_id": routeID.uuidString])
                .execute()
            return response.value.first
        }
    }

    private func execute<Value: Sendable>(
        _ operation: () async throws -> Value
    ) async throws -> Value {
        do {
            return try await operation()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw RemoteErrorMapping.map(error)
        }
    }
}
