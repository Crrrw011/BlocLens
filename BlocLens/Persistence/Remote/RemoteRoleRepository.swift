import Foundation
import Supabase

nonisolated protocol RemoteRoleDataSource: Sendable {
    func currentUserID() -> UUID?
    func fetchProfile() async throws -> UserProfileRecord?
    func isAdministrator() async throws -> Bool
    func isAdministratorOrModerator() async throws -> Bool
    func managedGyms() async throws -> [GymScopeRecord]
    func fetchNotificationPreferences() async throws -> [NotificationPreferenceRecord]
    func upsertNotificationPreference(userID: UUID, category: String, isEnabled: Bool) async throws
}

nonisolated struct NotificationPreferenceRecord: Codable, Equatable, Sendable {
    let category: String
    let isEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case category
        case isEnabled = "is_enabled"
    }
}

nonisolated struct NotificationPreferenceWrite: Encodable, Sendable {
    let userID: String
    let category: String
    let isEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case category
        case isEnabled = "is_enabled"
    }
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

    func fetchNotificationPreferences() async throws -> [NotificationPreferenceRecord] {
        let response: PostgrestResponse<[NotificationPreferenceRecord]> = try await client
            .from("notification_preferences")
            .select("category,is_enabled")
            .execute()
        return response.value
    }

    func upsertNotificationPreference(userID: UUID, category: String, isEnabled: Bool) async throws {
        let write = NotificationPreferenceWrite(
            userID: userID.uuidString, category: category, isEnabled: isEnabled
        )
        _ = try await client
            .from("notification_preferences")
            .upsert(write, onConflict: "user_id,category")
            .execute()
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

    func notificationPreferences() async throws -> [NotificationPreference] {
        guard dataSource.currentUserID() != nil else { throw RepositoryError.unauthenticated }
        do {
            let records = try await dataSource.fetchNotificationPreferences()
            return try records.map { record in
                guard let category = NotificationCategory(rawValue: record.category) else {
                    throw RepositoryError.decodingFailure
                }
                return NotificationPreference(category: category, isEnabled: record.isEnabled)
            }
        } catch is CancellationError { throw CancellationError() }
        catch let error as RepositoryError { throw error }
        catch { throw RemoteErrorMapping.map(error) }
    }

    func setNotificationPreference(category: NotificationCategory, isEnabled: Bool) async throws {
        guard let userID = dataSource.currentUserID() else { throw RepositoryError.unauthenticated }
        do {
            try await dataSource.upsertNotificationPreference(
                userID: userID, category: category.rawValue, isEnabled: isEnabled
            )
        } catch is CancellationError { throw CancellationError() }
        catch { throw RemoteErrorMapping.map(error) }
    }
}
