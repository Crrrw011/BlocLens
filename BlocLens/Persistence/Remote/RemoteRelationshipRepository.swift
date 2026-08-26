import Foundation
import Supabase

nonisolated protocol RemoteRelationshipDataSource: Sendable {
    func currentUserID() -> UUID?
    func fetchPublicProfiles() async throws -> [PublicProfileRecord]
    func fetchBlockedUserIDs(blockerID: UUID) async throws -> [UUID]
    func isFollowing(followerID: UUID, followedID: UUID) async throws -> Bool
    func isBlocked(blockerID: UUID, blockedID: UUID) async throws -> Bool
    func insertFollow(followerID: UUID, followedID: UUID) async throws
    func deleteFollow(followerID: UUID, followedID: UUID) async throws
    func insertBlock(blockerID: UUID, blockedID: UUID) async throws
    func deleteBlock(blockerID: UUID, blockedID: UUID) async throws
}

struct SupabaseRelationshipDataSource: RemoteRelationshipDataSource, Sendable {
    let client: SupabaseClient

    func currentUserID() -> UUID? { client.auth.currentUser?.id }

    func fetchPublicProfiles() async throws -> [PublicProfileRecord] {
        let response: PostgrestResponse<[PublicProfileRecord]> = try await client
            .from("public_profiles").select().execute()
        return response.value
    }

    func fetchBlockedUserIDs(blockerID: UUID) async throws -> [UUID] {
        let response: PostgrestResponse<[RelationshipBlockedIDRecord]> = try await client
            .from("user_blocks").select("blocked_id")
            .eq("blocker_id", value: blockerID.uuidString).execute()
        return response.value.map(\.blockedID)
    }

    func isFollowing(followerID: UUID, followedID: UUID) async throws -> Bool {
        let response: PostgrestResponse<[RelationshipMarker]> = try await client
            .from("user_follows").select("created_at")
            .eq("follower_id", value: followerID.uuidString)
            .eq("followed_id", value: followedID.uuidString).limit(1).execute()
        return !response.value.isEmpty
    }

    func isBlocked(blockerID: UUID, blockedID: UUID) async throws -> Bool {
        let response: PostgrestResponse<[RelationshipMarker]> = try await client
            .from("user_blocks").select("created_at")
            .eq("blocker_id", value: blockerID.uuidString)
            .eq("blocked_id", value: blockedID.uuidString).limit(1).execute()
        return !response.value.isEmpty
    }

    func insertFollow(followerID: UUID, followedID: UUID) async throws {
        _ = try await client.from("user_follows").insert([
            "follower_id": followerID.uuidString,
            "followed_id": followedID.uuidString
        ], returning: .minimal).execute()
    }

    func deleteFollow(followerID: UUID, followedID: UUID) async throws {
        _ = try await client.from("user_follows").delete(returning: .minimal)
            .eq("follower_id", value: followerID.uuidString)
            .eq("followed_id", value: followedID.uuidString).execute()
    }

    func insertBlock(blockerID: UUID, blockedID: UUID) async throws {
        _ = try await client.from("user_blocks").insert([
            "blocker_id": blockerID.uuidString,
            "blocked_id": blockedID.uuidString
        ], returning: .minimal).execute()
    }

    func deleteBlock(blockerID: UUID, blockedID: UUID) async throws {
        _ = try await client.from("user_blocks").delete(returning: .minimal)
            .eq("blocker_id", value: blockerID.uuidString)
            .eq("blocked_id", value: blockedID.uuidString).execute()
    }
}

actor RemoteRelationshipRepository: RelationshipRepository {
    private let dataSource: any RemoteRelationshipDataSource
    private var completedMutations: Set<IdempotencyKey> = []

    init(dataSource: any RemoteRelationshipDataSource) { self.dataSource = dataSource }

    func publicProfiles() async throws -> [PublicUserProfile] {
        let current = try requireUser()
        do {
            let blocked = Set(try await dataSource.fetchBlockedUserIDs(blockerID: current))
            return try await dataSource.fetchPublicProfiles()
                .filter { $0.id != current && !blocked.contains($0.id) }
                .map { try $0.domain() }
        } catch is CancellationError { throw CancellationError() }
        catch let error as RepositoryError { throw error }
        catch is RemoteMappingError { throw RepositoryError.decodingFailure }
        catch { throw RemoteErrorMapping.map(error) }
    }

    func state(with userID: UserID) async throws -> UserRelationshipState {
        let current = try requireUser()
        let other = try uuid(userID)
        do {
            async let following = dataSource.isFollowing(followerID: current, followedID: other)
            async let blocked = dataSource.isBlocked(blockerID: current, blockedID: other)
            let values = try await (following, blocked)
            return UserRelationshipState(isFollowing: values.0, isBlocked: values.1)
        } catch is CancellationError { throw CancellationError() }
        catch { throw RemoteErrorMapping.map(error) }
    }

    func follow(userID: UserID, idempotencyKey: IdempotencyKey) async throws {
        try await mutate(idempotencyKey, userID: userID) { current, other in
            guard !((try await self.dataSource.isBlocked(blockerID: current, blockedID: other))) else {
                throw RepositoryError.invalidState
            }
            do { try await self.dataSource.insertFollow(followerID: current, followedID: other) }
            catch where RemoteErrorMapping.map(error) == .conflict { return }
        }
    }

    func unfollow(userID: UserID, idempotencyKey: IdempotencyKey) async throws {
        try await mutate(idempotencyKey, userID: userID) { current, other in
            try await self.dataSource.deleteFollow(followerID: current, followedID: other)
        }
    }

    func block(userID: UserID, idempotencyKey: IdempotencyKey) async throws {
        try await mutate(idempotencyKey, userID: userID) { current, other in
            do { try await self.dataSource.insertBlock(blockerID: current, blockedID: other) }
            catch where RemoteErrorMapping.map(error) == .conflict { return }
        }
    }

    func unblock(userID: UserID, idempotencyKey: IdempotencyKey) async throws {
        try await mutate(idempotencyKey, userID: userID) { current, other in
            try await self.dataSource.deleteBlock(blockerID: current, blockedID: other)
        }
    }

    private func mutate(
        _ key: IdempotencyKey,
        userID: UserID,
        operation: (UUID, UUID) async throws -> Void
    ) async throws {
        guard !completedMutations.contains(key) else { return }
        let current = try requireUser()
        let other = try uuid(userID)
        guard current != other else { throw RepositoryError.invalidInput }
        do {
            try await operation(current, other)
            completedMutations.insert(key)
        } catch is CancellationError { throw CancellationError() }
        catch let error as RepositoryError { throw error }
        catch { throw RemoteErrorMapping.map(error) }
    }

    private func requireUser() throws -> UUID {
        guard let id = dataSource.currentUserID() else { throw RepositoryError.unauthenticated }
        return id
    }

    private func uuid(_ id: UserID) throws -> UUID {
        guard let value = UUID(uuidString: id.rawValue) else { throw RepositoryError.invalidInput }
        return value
    }
}

private struct RelationshipBlockedIDRecord: Decodable {
    let blockedID: UUID
    enum CodingKeys: String, CodingKey { case blockedID = "blocked_id" }
}

private struct RelationshipMarker: Decodable {
    let createdAt: Date
    enum CodingKeys: String, CodingKey { case createdAt = "created_at" }
}
