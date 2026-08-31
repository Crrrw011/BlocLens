import Foundation
import Supabase

nonisolated protocol RemoteAuthDataSource: Sendable {
    func hasSession() -> Bool
    func currentUserID() -> UUID?
    func signIn(email: String, password: String) async throws
    func signUp(email: String, password: String) async throws -> RemoteAuthSignUpResult
    func signInWithApple(idToken: String, nonce: String) async throws
    func signInWithGoogle() async throws
    func sendEmailOTP(email: String) async throws
    func verifyEmailOTP(email: String, token: String) async throws -> RemoteAuthSignUpResult
    func signOut() async throws
    func clearLocalSession() async throws
    func deleteAccount() async throws
    func updatePassword(_ password: String) async throws
    func fetchProfile() async throws -> UserProfileRecord?
    func updateUsername(_ username: String, userID: UUID) async throws
    func updateAgeConfirmation(userID: UUID) async throws
    func updateProfileDetails(_ details: ProfileDetailsUpdate, userID: UUID) async throws
}

nonisolated struct RemoteAuthSignUpResult: Equatable, Sendable {
    let userID: UUID
    let hasSession: Bool
}

nonisolated struct ProfileDetailsUpdate: Equatable, Sendable {
    let heightCentimetres: Double?
    let armSpanCentimetres: Double?
    let regularGrade: VGrade?
    let gradeSystem: GradeSystem?
    let ydsGrade: YDSGrade?
    let favouriteGymID: GymID?
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

    func signUp(email: String, password: String) async throws -> RemoteAuthSignUpResult {
        let response = try await client.auth.signUp(email: email, password: password)
        switch response {
        case .session(let session):
            return RemoteAuthSignUpResult(userID: session.user.id, hasSession: true)
        case .user(let user):
            return RemoteAuthSignUpResult(userID: user.id, hasSession: false)
        }
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

    func sendEmailOTP(email: String) async throws {
        try await client.auth.signInWithOTP(email: email, shouldCreateUser: true)
    }

    func verifyEmailOTP(email: String, token: String) async throws -> RemoteAuthSignUpResult {
        let response = try await client.auth.verifyOTP(
            email: email,
            token: token,
            type: .email
        )
        switch response {
        case .session(let session):
            return RemoteAuthSignUpResult(userID: session.user.id, hasSession: true)
        case .user(let user):
            return RemoteAuthSignUpResult(userID: user.id, hasSession: false)
        }
    }

    func updatePassword(_ password: String) async throws {
        try await client.auth.update(user: UserAttributes(password: password))
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    func clearLocalSession() async throws {
        try await client.auth.signOut(scope: .local)
    }

    func deleteAccount() async throws {
        try await client.functions.invoke("delete-account")
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

    func updateProfileDetails(_ details: ProfileDetailsUpdate, userID: UUID) async throws {
        var values: [String: AnyJSON] = [
            "height_cm": details.heightCentimetres.map { AnyJSON.double($0) } ?? AnyJSON.null,
            "arm_span_cm": details.armSpanCentimetres.map { AnyJSON.double($0) } ?? AnyJSON.null,
            "regular_grade": details.gradeSystem == .vScale
                ? (details.regularGrade.map { AnyJSON.integer($0.rawValue) } ?? AnyJSON.null)
                : AnyJSON.null,
            "grade_system": details.gradeSystem.map { AnyJSON.string($0.rawValue) } ?? AnyJSON.null,
            "yds_grade": details.gradeSystem == .yds
                ? (details.ydsGrade.map { AnyJSON.string($0.rawValue) } ?? AnyJSON.null)
                : AnyJSON.null,
            "favourite_gym_id": details.favouriteGymID.map { AnyJSON.string($0.rawValue) } ?? AnyJSON.null
        ]
        _ = try await client
            .from("profiles")
            .update(values, returning: .minimal)
            .eq("id", value: userID.uuidString)
            .execute()
    }
}
