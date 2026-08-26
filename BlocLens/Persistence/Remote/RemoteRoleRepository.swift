import Foundation
import Supabase

nonisolated protocol RemoteRoleDataSource: Sendable {
    func currentUserID() -> UUID?
    func fetchProfile() async throws -> UserProfileRecord?
    func isAdministrator() async throws -> Bool
    func isAdministratorOrModerator() async throws -> Bool
    func managedGyms() async throws -> [GymScopeRecord]
}

struct SupabaseRoleDataSource: RemoteRoleDataSource, Sendable {
    let client: SupabaseClient

    func currentUserID() -> UUID? { client.auth.currentUser?.id }

    func fetchProfile() async throws -> UserProfileRecord? {
        let response: PostgrestResponse<[UserProfileRecord]> = try await client.rpc("get_my_profile").execute()
        return response.value.first
    }

    func isAdministrator() async throws -> Bool {
        let response: PostgrestResponse<Bool> = try await client.rpc("is_admin").execute()
        return response.value
    }

    func isAdministratorOrModerator() async throws -> Bool {
        let response: PostgrestResponse<Bool> = try await client.rpc("is_admin_or_moderator").execute()
        return response.value
    }

    func managedGyms() async throws -> [GymScopeRecord] {
        let response: PostgrestResponse<[GymScopeRecord]> = try await client
            .from("gym_official_scope").select("gym_id").execute()
        return response.value
    }
}

actor RemoteRoleRepository: RoleRepository {
    private let dataSource: any RemoteRoleDataSource

    init(dataSource: any RemoteRoleDataSource) { self.dataSource = dataSource }

    func sessionRoleContext() async throws -> SessionRoleContext {
        guard dataSource.currentUserID() != nil else { throw RepositoryError.unauthenticated }
        do {
            async let profile = dataSource.fetchProfile()
            async let administrator = dataSource.isAdministrator()
            async let administratorOrModerator = dataSource.isAdministratorOrModerator()
            async let scopes = dataSource.managedGyms()
            let (resolvedProfile, isAdministrator, isPrivileged, managed) = try await (
                profile, administrator, administratorOrModerator, scopes
            )
            let role: SessionAppRole
            if isAdministrator {
                role = .administrator
            } else if isPrivileged {
                role = .moderator
            } else if resolvedProfile?.isTrustedContributor == true {
                role = .trustedContributor
            } else {
                role = .user
            }
            return SessionRoleContext(
                appRole: role,
                managedGymIDs: Set(managed.map { GymID(rawValue: RemoteIdentifier.domainString($0.gymID)) })
            )
        } catch is CancellationError { throw CancellationError() }
        catch { throw RemoteErrorMapping.map(error) }
    }
}
