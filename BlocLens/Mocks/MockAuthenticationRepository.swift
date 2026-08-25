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

    func signInWithMockAccount() -> UserProfile {
        authenticationState = .signedIn(profile)
        return profile
    }

    func signOut() { authenticationState = .guest }
}
