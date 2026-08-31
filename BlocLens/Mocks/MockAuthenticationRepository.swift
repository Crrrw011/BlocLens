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

    func signOut() throws -> AuthenticationState {
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

    func deleteAccount() throws -> AuthenticationState {
        authenticationState = .guest
        return authenticationState
    }

    func updateProfileDetails(_ details: ProfileDetailsUpdate) -> AuthenticationState {
        if case .signedIn(let current) = authenticationState {
            let updated = UserProfile(
                userID: current.userID,
                username: current.username,
                heightCentimetres: details.heightCentimetres ?? current.heightCentimetres,
                armSpanCentimetres: details.armSpanCentimetres ?? current.armSpanCentimetres,
                regularGrade: details.regularGrade ?? current.regularGrade,
                gradeSystem: details.gradeSystem ?? current.gradeSystem,
                ydsGrade: details.ydsGrade ?? current.ydsGrade,
                favouriteGymID: details.favouriteGymID ?? current.favouriteGymID,
                isTrustedContributor: current.isTrustedContributor,
                helpfulVotes: current.helpfulVotes
            )
            authenticationState = .signedIn(updated)
        } else if case .profileSetup(let current) = authenticationState {
            let updated = UserProfile(
                userID: current.userID,
                username: current.username,
                heightCentimetres: details.heightCentimetres ?? current.heightCentimetres,
                armSpanCentimetres: details.armSpanCentimetres ?? current.armSpanCentimetres,
                regularGrade: details.regularGrade ?? current.regularGrade,
                gradeSystem: details.gradeSystem ?? current.gradeSystem,
                ydsGrade: details.ydsGrade ?? current.ydsGrade,
                favouriteGymID: details.favouriteGymID ?? current.favouriteGymID,
                isTrustedContributor: current.isTrustedContributor,
                helpfulVotes: current.helpfulVotes
            )
            authenticationState = .profileSetup(updated)
        }
        return authenticationState
    }

    func sendEmailOTP(email: String) -> AuthenticationState {
        .authenticating
    }

    func verifyEmailOTP(email: String, token: String) -> AuthenticationState {
        authenticationState = .signedIn(profile)
        return authenticationState
    }

    func updatePassword(_ password: String) throws {
        // Mock keeps no password store; the call is accepted as a no-op.
    }
}
