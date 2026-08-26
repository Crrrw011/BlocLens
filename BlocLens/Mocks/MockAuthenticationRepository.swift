actor MockAuthenticationRepository: AuthenticationRepository {
    private var authenticationState: AuthenticationState
    private let profile: UserProfile

    init(
        initialState: AuthenticationState = .guest,
        profile: UserProfile = DevelopmentFixtures.mockProfile
    ) {
        authenticationState = initialState
        self.profile = profile
    }

    func state() -> AuthenticationState { authenticationState }

    func restoreSession() -> AuthenticationState {
        authenticationState
    }

    func signIn(email: String, password: String) -> AuthenticationState {
        authenticationState = .signedIn(profile)
        return authenticationState
    }

    func signUp(email: String, password: String) -> AuthenticationState {
        authenticationState = .signedIn(profile)
        return authenticationState
    }

    func updateUsername(_ username: String) -> AuthenticationState {
        authenticationState = .signedIn(profile)
        return authenticationState
    }

    func confirmAge(isOver16: Bool) -> AuthenticationState {
        authenticationState = isOver16 ? .signedIn(profile) : .ageGated
        return authenticationState
    }

    func signOut() -> AuthenticationState {
        authenticationState = .guest
        return authenticationState
    }

    func signInWithMockAccount() -> AuthenticationState {
        authenticationState = .signedIn(profile)
        return authenticationState
    }

    func signInWithApple(idToken: String, nonce: String) -> AuthenticationState {
        authenticationState = .signedIn(profile)
        return authenticationState
    }

    func signInWithGoogle() -> AuthenticationState {
        authenticationState = .signedIn(profile)
        return authenticationState
    }
}
