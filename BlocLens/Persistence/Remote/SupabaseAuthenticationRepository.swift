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
        } catch RepositoryError.unauthenticated {
            do {
                try await dataSource.clearLocalSession()
                currentState = .guest
            } catch let error as RepositoryError {
                currentState = .error(error)
            } catch {
                currentState = .error(RemoteErrorMapping.map(error))
            }
        } catch let error as RepositoryError {
            currentState = .error(error)
        } catch {
            currentState = .error(RemoteErrorMapping.map(error))
        }
        return currentState
    }

    func signIn(email: String, password: String) async -> AuthenticationState {
        do {
            try await dataSource.signIn(email: email, password: password)
            currentState = try await resolvedAuthenticatedSession()
        } catch let error as RepositoryError {
            currentState = .error(error)
        } catch {
            currentState = .error(RemoteErrorMapping.map(error))
        }
        return currentState
    }

    func signUp(email: String, password: String) async -> AuthenticationState {
        do {
            let result = try await dataSource.signUp(email: email, password: password)
            guard result.hasSession else {
                // The account was created but the session was not issued, which
                // means email confirmation is required before the user can sign in.
                currentState = .emailConfirmationRequired
                return currentState
            }
            guard dataSource.hasSession(), dataSource.currentUserID() == result.userID else {
                throw RepositoryError.persistenceError
            }
            currentState = try await resolvedAuthenticatedSession()
        } catch let error as RepositoryError {
            currentState = .error(error)
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
        } catch let error as RepositoryError {
            currentState = .error(error)
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
        } catch let error as RepositoryError {
            currentState = .error(error)
        } catch {
            currentState = .error(RemoteErrorMapping.map(error))
        }
        return currentState
    }

    func signOut() async throws -> AuthenticationState {
        do { try await dataSource.signOut() }
        catch is CancellationError { throw CancellationError() }
        catch {
            // The SDK clears the local session before it attempts the server
            // logout. If the server call fails, the local session is already
            // gone, so the user is signed out locally rather than still signed
            // in. Only surface an error when a session actually remains.
            if dataSource.hasSession() {
                throw RemoteErrorMapping.map(error)
            }
        }
        currentState = .guest
        return currentState
    }

    func signInWithApple(idToken: String, nonce: String) async -> AuthenticationState {
        do {
            try await dataSource.signInWithApple(idToken: idToken, nonce: nonce)
            currentState = try await resolvedAuthenticatedSession()
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
            currentState = try await resolvedAuthenticatedSession()
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

    func deleteAccount() async throws -> AuthenticationState {
        do {
            try await dataSource.deleteAccount()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw RemoteErrorMapping.map(error)
        }
        currentState = .guest
        return currentState
    }

    func updateProfileDetails(_ details: ProfileDetailsUpdate) async -> AuthenticationState {
        do {
            guard let userID = dataSource.currentUserID() else {
                currentState = .error(.unauthenticated)
                return currentState
            }
            try await dataSource.updateProfileDetails(details, userID: userID)
            currentState = try await resolvedCurrentSession()
        } catch let error as RepositoryError {
            currentState = .error(error)
        } catch {
            currentState = .error(RemoteErrorMapping.map(error))
        }
        return currentState
    }

    func sendEmailOTP(email: String) async -> AuthenticationState {
        do {
            try await dataSource.sendEmailOTP(email: email)
            return .authenticating
        } catch let error as RepositoryError {
            currentState = .error(error)
            return currentState
        } catch {
            currentState = .error(RemoteErrorMapping.map(error))
            return currentState
        }
    }

    func verifyEmailOTP(email: String, token: String) async -> AuthenticationState {
        do {
            let result = try await dataSource.verifyEmailOTP(email: email, token: token)
            guard result.hasSession else {
                currentState = .emailConfirmationRequired
                return currentState
            }
            guard dataSource.hasSession(), dataSource.currentUserID() == result.userID else {
                throw RepositoryError.persistenceError
            }
            currentState = try await resolvedAuthenticatedSession()
        } catch let error as RepositoryError {
            currentState = .error(error)
        } catch {
            currentState = .error(RemoteErrorMapping.map(error))
        }
        return currentState
    }

    func updatePassword(_ password: String) async throws {
        do {
            try await dataSource.updatePassword(password)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw RemoteErrorMapping.map(error)
        }
    }

    private func resolvedCurrentSession() async throws -> AuthenticationState {
        guard dataSource.hasSession() else { return .guest }
        return try await resolvedAuthenticatedSession()
    }

    private func resolvedAuthenticatedSession() async throws -> AuthenticationState {
        guard dataSource.hasSession() else { throw RepositoryError.persistenceError }
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
