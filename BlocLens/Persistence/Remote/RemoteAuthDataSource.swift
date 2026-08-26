import Foundation
import Supabase

nonisolated protocol RemoteAuthDataSource: Sendable {
    func hasSession() -> Bool
    func currentUserID() -> UUID?
    func signIn(email: String, password: String) async throws
    func signUp(email: String, password: String) async throws
    func signInWithApple(idToken: String, nonce: String) async throws
    func signInWithGoogle() async throws
    func signOut() async throws
    func fetchProfile() async throws -> UserProfileRecord?
    func updateUsername(_ username: String, userID: UUID) async throws
    func updateAgeConfirmation(userID: UUID) async throws
}

struct SupabaseAuthDataSource: RemoteAuthDataSource, Sendable {
    let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func hasSession() -> Bool {
        client.auth.currentSession != nil
    }

    func currentUserID() -> UUID? {
        client.auth.currentUser?.id
    }

    func signIn(email: String, password: String) async throws {
        _ = try await client.auth.signIn(email: email, password: password)
    }

    func signUp(email: String, password: String) async throws {
        _ = try await client.auth.signUp(email: email, password: password)
    }

    func signInWithApple(idToken: String, nonce: String) async throws {
        _ = try await client.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(
                provider: .apple,
                idToken: idToken,
                nonce: nonce
            )
        )
    }

    func signInWithGoogle() async throws {
        _ = try await client.auth.signInWithOAuth(
            provider: .google,
            redirectTo: URL(string: "bloclens://")
        )
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    func fetchProfile() async throws -> UserProfileRecord? {
        let response: PostgrestResponse<[UserProfileRecord]> = try await client
            .rpc("get_my_profile")
            .execute()
        return response.value.first
    }

    func updateUsername(_ username: String, userID: UUID) async throws {
        _ = try await client
            .from("profiles")
            .update(["username": username], returning: .minimal)
            .eq("id", value: userID.uuidString)
            .execute()
    }

    func updateAgeConfirmation(userID: UUID) async throws {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestamp = formatter.string(from: Date())
        _ = try await client
            .from("profiles")
            .update(["age_confirmed_16_plus_at": timestamp], returning: .minimal)
            .eq("id", value: userID.uuidString)
            .execute()
    }
}
