import Foundation
import Supabase
import Testing
@testable import BlocLens

@MainActor
struct AuthStateMachineTests {
    private func makeProfile(username: String, ageConfirmed: Date?) -> UserProfileRecord {
        UserProfileRecord(
            id: UUID(), username: username, avatarPath: nil, heightCM: nil, armSpanCM: nil,
            regularGrade: nil, favouriteGymID: nil, isTrustedContributor: false,
            helpfulReceivedCount: 0, ageConfirmed16PlusAt: ageConfirmed,
            createdAt: Date(), updatedAt: Date()
        )
    }

    // MARK: - Auth error mapping

    @Test func authErrorMappingDistinguishesCases() throws {
        #expect(RemoteErrorMapping.map(AuthError.sessionMissing) == .unauthenticated)
        #expect(RemoteErrorMapping.map(AuthError.weakPassword(message: "weak", reasons: [])) == .invalidInput)

        #expect(RemoteErrorMapping.map(try makeAuthAPIError("invalid_credentials")) == .unauthenticated)
        #expect(RemoteErrorMapping.map(try makeAuthAPIError("user_not_found")) == .notFound)
        #expect(RemoteErrorMapping.map(try makeAuthAPIError("email_exists")) == .conflict)
    }

    private func makeAuthAPIError(_ code: String) throws -> AuthError {
        let url = try #require(URL(string: "https://example.com"))
        let response = try #require(
            HTTPURLResponse(url: url, statusCode: 400, httpVersion: nil, headerFields: [:])
        )
        return AuthError.api(
            message: "auth error",
            errorCode: ErrorCode(code),
            underlyingData: Data(),
            underlyingResponse: response
        )
    }

    // MARK: - State machine

    @Test func repositoryStartsSignedOut() async throws {
        let repository = SupabaseAuthenticationRepository(dataSource: FakeAuthDataSource())
        #expect(await repository.state() == .guest)
    }

    @Test func restoreSessionWithoutSessionReturnsGuest() async throws {
        let fake = FakeAuthDataSource()
        let repository = SupabaseAuthenticationRepository(dataSource: fake)
        let state = await repository.restoreSession()
        #expect(state == .guest)
    }

    @Test func restoreSessionWithSessionReturnsSignedIn() async throws {
        let fake = FakeAuthDataSource(
            hasSession: true,
            profile: makeProfile(username: "alice", ageConfirmed: Date())
        )
        let repository = SupabaseAuthenticationRepository(dataSource: fake)
        let state = await repository.restoreSession()
        guard case .signedIn = state else {
            Issue.record("Expected signedIn, got \(state)")
            return
        }
    }

    @Test func signInSuccessReturnsSignedIn() async throws {
        let fake = FakeAuthDataSource(
            hasSession: true,
            profile: makeProfile(username: "alice", ageConfirmed: Date())
        )
        let repository = SupabaseAuthenticationRepository(dataSource: fake)
        let state = await repository.signIn(email: "alice@example.com", password: "password123")
        guard case .signedIn = state else {
            Issue.record("Expected signedIn, got \(state)")
            return
        }
    }

    @Test func signInFailureReturnsErrorUnauthenticated() async throws {
        let fake = FakeAuthDataSource(signInError: try makeAuthAPIError("invalid_credentials"))
        let repository = SupabaseAuthenticationRepository(dataSource: fake)
        let state = await repository.signIn(email: "alice@example.com", password: "wrong")
        #expect(state == .error(.unauthenticated))
    }

    @Test func signUpWithoutServerSessionRequiresEmailConfirmation() async throws {
        let fake = FakeAuthDataSource(signUpHasSession: false)
        let repository = SupabaseAuthenticationRepository(dataSource: fake)

        let state = await repository.signUp(email: "alice@example.com", password: "password123")

        #expect(state == .emailConfirmationRequired)
        #expect(!fake.hasSession())
    }

    @Test func signOutReturnsGuest() async throws {
        let fake = FakeAuthDataSource(hasSession: true, profile: makeProfile(username: "alice", ageConfirmed: Date()))
        let repository = SupabaseAuthenticationRepository(dataSource: fake)
        let state = try await repository.signOut()
        #expect(state == .guest)
    }

    @Test func signOutFailurePreservesAuthenticatedRepositoryState() async throws {
        let profile = makeProfile(username: "alice", ageConfirmed: Date())
        let fake = FakeAuthDataSource(hasSession: true, profile: profile)
        fake.signOutError = URLError(.cannotConnectToHost)
        let repository = SupabaseAuthenticationRepository(dataSource: fake)
        _ = await repository.restoreSession()

        await #expect(throws: RepositoryError.network) {
            _ = try await repository.signOut()
        }
        guard case .signedIn = await repository.state() else {
            Issue.record("A failed SDK sign-out must preserve the authenticated state")
            return
        }
    }

    @Test func firstLoginWithoutUsernameEntersProfileSetup() async throws {
        let fake = FakeAuthDataSource(
            hasSession: true,
            profile: makeProfile(username: "climber_abc123", ageConfirmed: nil)
        )
        let repository = SupabaseAuthenticationRepository(dataSource: fake)
        let state = await repository.restoreSession()
        guard case .profileSetup = state else {
            Issue.record("Expected profileSetup, got \(state)")
            return
        }
    }

    @Test func updateUsernameCompletesSetup() async throws {
        let fake = FakeAuthDataSource(
            hasSession: true,
            profile: makeProfile(username: "climber_abc123", ageConfirmed: Date())
        )
        fake.profileAfterUsernameUpdate = makeProfile(username: "alice", ageConfirmed: Date())
        let repository = SupabaseAuthenticationRepository(dataSource: fake)
        let afterSignIn = await repository.signIn(email: "a@b.c", password: "password123")
        guard case .profileSetup = afterSignIn else {
            Issue.record("Expected profileSetup, got \(afterSignIn)")
            return
        }
        let state = await repository.updateUsername("alice")
        guard case .signedIn = state else {
            Issue.record("Expected signedIn, got \(state)")
            return
        }
    }

    @Test func duplicateUsernameReturnsConflict() async throws {
        let fake = FakeAuthDataSource(
            hasSession: true,
            profile: makeProfile(username: "climber_abc123", ageConfirmed: Date())
        )
        fake.updateUsernameError = PostgrestError(code: "23505", message: "duplicate")
        let repository = SupabaseAuthenticationRepository(dataSource: fake)
        let state = await repository.updateUsername("taken")
        #expect(state == .error(.conflict))
    }

    @Test func confirmAgeOver16Continues() async throws {
        let fake = FakeAuthDataSource(
            hasSession: true,
            profile: makeProfile(username: "climber_abc123", ageConfirmed: nil)
        )
        let repository = SupabaseAuthenticationRepository(dataSource: fake)
        let state = await repository.confirmAge(isOver16: true)
        guard case .profileSetup = state else {
            Issue.record("Expected profileSetup, got \(state)")
            return
        }
    }

    @Test func confirmAgeUnder16Gates() async throws {
        let fake = FakeAuthDataSource()
        let repository = SupabaseAuthenticationRepository(dataSource: fake)
        let state = await repository.confirmAge(isOver16: false)
        #expect(state == .ageGated)
    }

    // MARK: - Environment wiring

    @Test func mockEnvironmentUsesMockAuthentication() async throws {
        let environment = AppEnvironment.development()
        #expect(environment.authenticationRepository is MockAuthenticationRepository)
    }

    @Test func localSupabaseWiresRemoteAuthentication() throws {
        let url = try #require(URL(string: "http://127.0.0.1:54321"))
        let config = try RemoteConfiguration(mode: .localDevelopment, projectURL: url, publishableKey: "key")
        let environment = AppEnvironment.localSupabase(configuration: config)
        #expect(environment.authenticationRepository is SupabaseAuthenticationRepository)
    }

    @Test func cloudSupabaseWiresOneRemoteEnvironment() throws {
        let url = try #require(URL(string: "https://project-ref.supabase.co"))
        let config = try RemoteConfiguration(mode: .production, projectURL: url, publishableKey: "key")
        let environment = AppEnvironment.cloudSupabase(configuration: config)
        #expect(environment.authenticationRepository is SupabaseAuthenticationRepository)
        #expect(environment.gymRepository is RemoteGymRepository)
        #expect(environment.routeRepository is RemoteRouteRepository)
        #expect(environment.betaRepository is RemoteBetaRepository)
        #expect(environment.logbookRepository is RemoteLogbookRepository)
    }

    @Test func pendingActionRestoresAfterEmailSignIn() async {
        let environment = AppEnvironment.development()
        let session = AppSession(environment: environment)
        await session.load()
        let intent: ProtectedIntent = .revealBeta(routeID: ClimbingRouteID(rawValue: "route-1"))
        #expect(!session.requireAuthentication(for: intent))
        await session.signIn(email: "alice@example.com", password: "password123")
        #expect(session.resumedIntent == intent)
    }

    // MARK: - OAuth

    @Test func appleSignInSuccessReturnsSignedIn() async throws {
        let fake = FakeAuthDataSource(
            hasSession: true,
            profile: makeProfile(username: "alice", ageConfirmed: Date())
        )
        let repository = SupabaseAuthenticationRepository(dataSource: fake)
        let state = await repository.signInWithApple(idToken: "valid-token", nonce: "valid-nonce")
        guard case .signedIn = state else {
            Issue.record("Expected signedIn, got \(state)")
            return
        }
        #expect(fake.receivedAppleNonce == "valid-nonce")
    }

    @Test func appleSignInCancellationMapsToUserCancelled() async throws {
        let fake = FakeAuthDataSource()
        fake.appleSignInError = RepositoryError.userCancelled
        let repository = SupabaseAuthenticationRepository(dataSource: fake)
        let state = await repository.signInWithApple(idToken: "token", nonce: "nonce")
        #expect(state == .error(.userCancelled))
    }

    @Test func googleSignInSuccessReturnsSignedIn() async throws {
        let fake = FakeAuthDataSource(
            hasSession: true,
            profile: makeProfile(username: "alice", ageConfirmed: Date())
        )
        let repository = SupabaseAuthenticationRepository(dataSource: fake)
        let state = await repository.signInWithGoogle()
        guard case .signedIn = state else {
            Issue.record("Expected signedIn, got \(state)")
            return
        }
    }

    @Test func googleSignInConfigurationFailureMapsToInvalidConfiguration() async throws {
        let fake = FakeAuthDataSource()
        fake.googleSignInError = RepositoryError.invalidConfiguration
        let repository = SupabaseAuthenticationRepository(dataSource: fake)
        let state = await repository.signInWithGoogle()
        #expect(state == .error(.invalidConfiguration))
    }

    @Test func mockAuthenticationSupportsOAuth() async throws {
        let repository = MockAuthenticationRepository()
        let appleState = await repository.signInWithApple(idToken: "token", nonce: "nonce")
        guard case .signedIn = appleState else {
            Issue.record("Expected signedIn, got \(appleState)")
            return
        }
        let googleState = await repository.signInWithGoogle()
        guard case .signedIn = googleState else {
            Issue.record("Expected signedIn, got \(googleState)")
            return
        }
    }

    @Test func oauthWithoutServerProfileDoesNotCreatePlaceholderIdentity() async throws {
        let fake = FakeAuthDataSource(hasSession: true)
        let repository = SupabaseAuthenticationRepository(dataSource: fake)
        let state = await repository.signInWithGoogle()
        #expect(state == .error(.notFound))
    }
}

private final class FakeAuthDataSource: RemoteAuthDataSource, @unchecked Sendable {
    var hasSessionFlag: Bool
    var userIDValue: UUID?
    var profileValue: UserProfileRecord?
    var signInError: Error?
    var signUpError: Error?
    var updateUsernameError: Error?
    var appleSignInError: Error?
    var googleSignInError: Error?
    var signOutError: Error?
    var deleteAccountError: Error?
    var signUpHasSession: Bool
    var profileAfterUsernameUpdate: UserProfileRecord?
    var receivedAppleNonce: String?

    init(
        hasSession: Bool = false,
        userID: UUID? = nil,
        profile: UserProfileRecord? = nil,
        signInError: Error? = nil,
        signUpError: Error? = nil,
        updateUsernameError: Error? = nil,
        signUpHasSession: Bool = true
    ) {
        hasSessionFlag = hasSession
        userIDValue = userID ?? profile?.id
        profileValue = profile
        self.signInError = signInError
        self.signUpError = signUpError
        self.updateUsernameError = updateUsernameError
        self.signUpHasSession = signUpHasSession
    }

    func hasSession() -> Bool { hasSessionFlag }

    func currentUserID() -> UUID? { userIDValue }

    func signIn(email: String, password: String) async throws {
        if let signInError { throw signInError }
        hasSessionFlag = true
    }

    func signUp(email: String, password: String) async throws -> RemoteAuthSignUpResult {
        if let signUpError { throw signUpError }
        hasSessionFlag = signUpHasSession
        let userID = userIDValue ?? UUID()
        userIDValue = userID
        return RemoteAuthSignUpResult(userID: userID, hasSession: signUpHasSession)
    }

    func signInWithApple(idToken: String, nonce: String) async throws {
        if let appleSignInError { throw appleSignInError }
        receivedAppleNonce = nonce
        hasSessionFlag = true
    }

    func signInWithGoogle() async throws {
        if let googleSignInError { throw googleSignInError }
        hasSessionFlag = true
    }

    func signOut() async throws {
        if let signOutError { throw signOutError }
        hasSessionFlag = false
        userIDValue = nil
    }

    func deleteAccount() async throws {
        if let deleteAccountError { throw deleteAccountError }
        hasSessionFlag = false
        userIDValue = nil
    }

    func fetchProfile() async throws -> UserProfileRecord? { profileValue }

    func updateUsername(_ username: String, userID: UUID) async throws {
        if let updateUsernameError { throw updateUsernameError }
        if let profileAfterUsernameUpdate {
            profileValue = profileAfterUsernameUpdate
        }
    }

    func updateAgeConfirmation(userID: UUID) async throws {}
}
