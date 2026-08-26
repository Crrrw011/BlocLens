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
            currentState = try await resolvedCurrentSession()
        } catch {
            currentState = .error(RemoteErrorMapping.map(error))
        }
        return currentState
    }

    func signIn(email: String, password: String) async -> AuthenticationState {
        do {
            try await dataSource.signIn(email: email, password: password)
            currentState = try await resolvedCurrentSession()
        } catch {
            currentState = .error(RemoteErrorMapping.map(error))
        }
        return currentState
    }

    func signUp(email: String, password: String) async -> AuthenticationState {
        do {
            try await dataSource.signUp(email: email, password: password)
            currentState = try await resolvedCurrentSession()
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
            currentState = try await resolvedCurrentSession()
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
            currentState = try await resolvedCurrentSession()
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

    func signInWithApple(idToken: String, nonce: String) async -> AuthenticationState {
        do {
            try await dataSource.signInWithApple(idToken: idToken, nonce: nonce)
            currentState = try await resolvedCurrentSession()
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
            currentState = try await resolvedCurrentSession()
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

    private func resolvedCurrentSession() async throws -> AuthenticationState {
        guard dataSource.hasSession() else { return .guest }
        guard let record = try await dataSource.fetchProfile() else {
            throw RepositoryError.notFound
        }
        return try Self.resolveState(from: record)
    }

    private static func resolveState(from record: UserProfileRecord) throws -> AuthenticationState {
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

}
