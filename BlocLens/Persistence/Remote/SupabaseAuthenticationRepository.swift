import Foundation
import Supabase

actor SupabaseAuthenticationRepository: AuthenticationRepository {
    private let dataSource: any RemoteAuthDataSource
    private var currentState: AuthenticationState = .guest

    init(dataSource: any RemoteAuthDataSource) {
        self.dataSource = dataSource
    }

    func state() async -> AuthenticationState { currentState }

    func restoreSession() async -> AuthenticationState {
        do {
            guard dataSource.hasSession() else {
                currentState = .guest
                return currentState
            }
            let record = try await dataSource.fetchProfile()
            currentState = try Self.resolveState(from: record)
        } catch {
            currentState = .error(RemoteErrorMapping.map(error))
        }
        return currentState
    }

    func signIn(email: String, password: String) async -> AuthenticationState {
        do {
            try await dataSource.signIn(email: email, password: password)
            let record = try await dataSource.fetchProfile()
            currentState = try Self.resolveState(from: record)
        } catch {
            currentState = .error(RemoteErrorMapping.map(error))
        }
        return currentState
    }

    func signUp(email: String, password: String) async -> AuthenticationState {
        do {
            try await dataSource.signUp(email: email, password: password)
            let record = try await dataSource.fetchProfile()
            currentState = try Self.resolveState(from: record)
        } catch {
            currentState = .error(RemoteErrorMapping.map(error))
        }
        return currentState
    }

    func updateUsername(_ username: String) async -> AuthenticationState {
        do {
            guard let userID = dataSource.currentUserID() else {
                currentState = .error(.unauthenticated)
                return currentState
            }
            try await dataSource.updateUsername(username, userID: userID)
            let record = try await dataSource.fetchProfile()
            currentState = try Self.resolveState(from: record)
        } catch {
            currentState = .error(RemoteErrorMapping.map(error))
        }
        return currentState
    }

    func confirmAge(isOver16: Bool) async -> AuthenticationState {
        guard isOver16 else {
            currentState = .ageGated
            return currentState
        }
        do {
            guard let userID = dataSource.currentUserID() else {
                currentState = .error(.unauthenticated)
                return currentState
            }
            try await dataSource.updateAgeConfirmation(userID: userID)
            let record = try await dataSource.fetchProfile()
            currentState = try Self.resolveState(from: record)
        } catch {
            currentState = .error(RemoteErrorMapping.map(error))
        }
        return currentState
    }

    func signOut() async -> AuthenticationState {
        do {
            try await dataSource.signOut()
        } catch {
            // Even when the remote sign-out fails, the local state is cleared.
        }
        currentState = .guest
        return currentState
    }

    func signInWithApple(idToken: String) async -> AuthenticationState {
        do {
            try await dataSource.signInWithApple(idToken: idToken)
            currentState = .signedIn(Self.oauthPlaceholderProfile())
        } catch let error as RepositoryError {
            currentState = .error(error)
        } catch {
            currentState = .error(RemoteErrorMapping.map(error))
        }
        return currentState
    }

    func signInWithGoogle() async -> AuthenticationState {
        do {
            try await dataSource.signInWithGoogle()
            currentState = .signedIn(Self.oauthPlaceholderProfile())
        } catch let error as RepositoryError {
            currentState = .error(error)
        } catch {
            currentState = .error(RemoteErrorMapping.map(error))
        }
        return currentState
    }

    func signInWithMockAccount() async -> AuthenticationState {
        .guest
    }

    private static func resolveState(from record: UserProfileRecord?) throws -> AuthenticationState {
        guard let record else { return .guest }
        let profile: UserProfile
        do {
            profile = try record.domain()
        } catch {
            throw RepositoryError.decodingFailure
        }
        let needsSetup = record.ageConfirmed16PlusAt == nil
            || record.username.lowercased().hasPrefix("climber_")
        return needsSetup ? .profileSetup(profile) : .signedIn(profile)
    }

    private static func oauthPlaceholderProfile() -> UserProfile {
        UserProfile(
            userID: UserID(rawValue: UUID().uuidString.lowercased()),
            username: "oauth-user",
            heightCentimetres: nil,
            armSpanCentimetres: nil,
            regularGrade: nil,
            favouriteGymID: nil,
            isTrustedContributor: false,
            helpfulVotes: 0
        )
    }
}
