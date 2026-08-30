import Combine
import Supabase
import SwiftUI

struct AppEnvironment: Sendable {
    let gymRepository: any GymRepository
    let routeRepository: any RouteRepository
    let betaRepository: any BetaRepository
    let logbookRepository: any LogbookRepository
    let contributionRepository: any ContributionRepository
    let relationshipRepository: any RelationshipRepository
    let roleRepository: any RoleRepository
    let authenticationRepository: any AuthenticationRepository
    let onboardingStore: any OnboardingStore
    let languagePreferenceStore: any LanguagePreferenceStore
    let googlePlacesClient: any GooglePlacesClient
    let currentUserID: @Sendable () -> UserID?
    let dataAvailability: DataAvailability

    static func development(
        scenario: MockRepositoryScenario = .loaded,
        isOnline: Bool = true,
        isOnboardingComplete: Bool = true,
        authenticationState: AuthenticationState = .guest,
        onboardingStore: (any OnboardingStore)? = nil,
        languagePreferenceStore: any LanguagePreferenceStore = InMemoryLanguagePreferenceStore()
    ) -> AppEnvironment {
        AppEnvironment(
            gymRepository: MockGymRepository(scenario: scenario),
            routeRepository: MockRouteRepository(scenario: scenario),
            betaRepository: MockBetaRepository(scenario: scenario),
            logbookRepository: MockLogbookRepository(isOnline: isOnline),
            contributionRepository: MockContributionRepository(),
            relationshipRepository: MockRelationshipRepository(),
            roleRepository: MockRoleRepository(
                context: authenticationState.profile.map {
                    SessionRoleContext(
                        appRole: $0.isTrustedContributor ? .trustedContributor : .user,
                        managedGymIDs: []
                    )
                } ?? .guest
            ),
            authenticationRepository: MockAuthenticationRepository(initialState: authenticationState),
            onboardingStore: onboardingStore ?? InMemoryOnboardingStore(isComplete: isOnboardingComplete),
            languagePreferenceStore: languagePreferenceStore,
            googlePlacesClient: NoopGooglePlacesClient(),
            currentUserID: { DevelopmentFixtures.currentUserID },
            dataAvailability: scenario == .offlineWithCache ? .offlineCached : .online
        )
    }

    static func localSupabase(
        configuration: RemoteConfiguration,
        client: SupabaseClient? = nil
    ) -> AppEnvironment {
        supabase(configuration: configuration, client: client)
    }

    static func cloudSupabase(configuration: RemoteConfiguration) -> AppEnvironment {
        supabase(configuration: configuration)
    }

    private static func supabase(
        configuration: RemoteConfiguration,
        client providedClient: SupabaseClient? = nil
    ) -> AppEnvironment {
        let client = providedClient ?? SupabaseClientFactory.makeClient(configuration: configuration)
        let dataSource = SupabaseRemoteDataSource(client: client)
        let logbookQueue = FileBackedLogbookQueue(
            fileURL: Self.logbookQueueFileURL()
        )
        return AppEnvironment(
            gymRepository: RemoteGymRepository(dataSource: dataSource),
            routeRepository: RemoteRouteRepository(dataSource: dataSource),
            betaRepository: RemoteBetaRepository(dataSource: SupabaseBetaDataSource(client: client)),
            logbookRepository: RemoteLogbookRepository(
                dataSource: SupabaseLogbookDataSource(client: client),
                queue: logbookQueue
            ),
            contributionRepository: RemoteContributionRepository(
                dataSource: SupabaseContributionDataSource(client: client)
            ),
            relationshipRepository: RemoteRelationshipRepository(
                dataSource: SupabaseRelationshipDataSource(client: client)
            ),
            roleRepository: RemoteRoleRepository(
                dataSource: SupabaseRoleDataSource(client: client)
            ),
            authenticationRepository: SupabaseAuthenticationRepository(
                dataSource: SupabaseAuthDataSource(client: client)
            ),
            onboardingStore: InMemoryOnboardingStore(isComplete: true),
            languagePreferenceStore: InMemoryLanguagePreferenceStore(),
            googlePlacesClient: GooglePlacesClientFactory.makeFromBundle(),
            currentUserID: {
                client.auth.currentUser.map {
                    UserID(rawValue: RemoteIdentifier.domainString($0.id))
                }
            },
            dataAvailability: .online
        )
    }

    private static func logbookQueueFileURL() -> URL {
        let directory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        return directory.appendingPathComponent("bloclens-logbook-queue.json")
    }
}

@MainActor
final class AppSession: ObservableObject {
    @Published private(set) var hasLoaded = false
    @Published private(set) var hasCompletedOnboarding = false
    @Published private(set) var authenticationState: AuthenticationState = .guest
    @Published var selectedTab = AppTab.defaultSelected
    @Published var isSignInGatePresented = false
    @Published private(set) var pendingIntent: ProtectedIntent?
    @Published private(set) var resumedIntent: ProtectedIntent?
    @Published var hasAcknowledgedRevealSafety = false
    @Published var appearancePreference: AppearancePreference = .system
    @Published private(set) var languagePreference: LanguagePreference = .system
    @Published private(set) var dismissedContributionPrompts: Set<String> = []
    @Published private(set) var roleContext: SessionRoleContext = .guest
    @Published private(set) var isRoleContextConfirmed = true
    @Published private(set) var sessionError: RepositoryError?
    @Published var shouldPresentProfileSetup = false

    private let authenticationRepository: any AuthenticationRepository
    private let onboardingStore: any OnboardingStore
    private let languagePreferenceStore: any LanguagePreferenceStore
    private let roleRepository: any RoleRepository

    init(environment: AppEnvironment) {
        authenticationRepository = environment.authenticationRepository
        onboardingStore = environment.onboardingStore
        languagePreferenceStore = environment.languagePreferenceStore
        roleRepository = environment.roleRepository
        languagePreference = environment.languagePreferenceStore.preference()
    }

    func load() async {
        hasCompletedOnboarding = onboardingStore.isComplete()
        authenticationState = await authenticationRepository.restoreSession()
        await refreshRoleContext()
        hasLoaded = true
    }

    func completeOnboarding() {
        onboardingStore.setComplete(true)
        hasCompletedOnboarding = true
        selectedTab = .map
    }

    func resetOnboarding() {
        onboardingStore.setComplete(false)
        hasCompletedOnboarding = false
        selectedTab = .map
    }

    @discardableResult
    func requireAuthentication(for intent: ProtectedIntent) -> Bool {
        guard !authenticationState.isSignedIn else { return true }
        pendingIntent = intent
        isSignInGatePresented = true
        return false
    }

    func signInWithMockAccount() async {
        authenticationState = await authenticationRepository.signInWithMockAccount()
        completeSignInIfPossible()
    }

    func restoreSession() async {
        authenticationState = await authenticationRepository.restoreSession()
    }

    func signIn(email: String, password: String) async {
        authenticationState = .authenticating
        authenticationState = await authenticationRepository.signIn(email: email, password: password)
        completeSignInIfPossible()
    }

    func signUp(email: String, password: String) async {
        authenticationState = .authenticating
        authenticationState = await authenticationRepository.signUp(email: email, password: password)
    }

    func signInWithApple(idToken: String, nonce: String) async {
        authenticationState = .authenticating
        authenticationState = await authenticationRepository.signInWithApple(idToken: idToken, nonce: nonce)
        completeSignInIfPossible()
    }

    func signInWithGoogle() async {
        authenticationState = .authenticating
        authenticationState = await authenticationRepository.signInWithGoogle()
        completeSignInIfPossible()
    }

    func updateUsername(_ username: String) async {
        authenticationState = await authenticationRepository.updateUsername(username)
        completeSignInIfPossible()
    }

    func updateProfileDetails(_ details: ProfileDetailsUpdate) async {
        authenticationState = await authenticationRepository.updateProfileDetails(details)
    }

    func sendEmailOTP(email: String) async {
        authenticationState = await authenticationRepository.sendEmailOTP(email: email)
    }

    func verifyEmailOTP(email: String, token: String) async {
        authenticationState = .authenticating
        authenticationState = await authenticationRepository.verifyEmailOTP(email: email, token: token)
        completeSignInIfPossible()
    }

    func updatePassword(_ password: String) async throws {
        try await authenticationRepository.updatePassword(password)
    }

    func flagProfileSetupForPresentation() {
        shouldPresentProfileSetup = true
    }

    func confirmAge(isOver16: Bool) async {
        authenticationState = await authenticationRepository.confirmAge(isOver16: isOver16)
    }

    func failSignIn(_ error: RepositoryError) {
        authenticationState = .error(error)
    }

    private func completeSignInIfPossible() {
        if case .signedIn = authenticationState {
            resumedIntent = pendingIntent
            pendingIntent = nil
            isSignInGatePresented = false
            CrashReportingService.syncUser(authenticationState.profile?.userID)
            Task { await refreshRoleContext() }
        }
    }

    func cancelSignIn() {
        pendingIntent = nil
        isSignInGatePresented = false
    }

    func consumeResumedIntent(_ intent: ProtectedIntent) {
        guard resumedIntent == intent else { return }
        resumedIntent = nil
    }

    func signOut() async {
        do {
            authenticationState = try await authenticationRepository.signOut()
            pendingIntent = nil
            resumedIntent = nil
            isSignInGatePresented = false
            roleContext = .guest
            isRoleContextConfirmed = true
            sessionError = nil
            CrashReportingService.syncUser(nil)
        } catch let error as RepositoryError {
            sessionError = error
        } catch {
            sessionError = .unknown
        }
    }

    func deleteAccount() async throws {
        authenticationState = try await authenticationRepository.deleteAccount()
        pendingIntent = nil
        resumedIntent = nil
        isSignInGatePresented = false
        roleContext = .guest
        isRoleContextConfirmed = true
        sessionError = nil
        CrashReportingService.syncUser(nil)
    }

    func dismissContributionPrompt(_ identifier: String) {
        dismissedContributionPrompts.insert(identifier)
    }

    func isContributionPromptVisible(_ identifier: String) -> Bool {
        !dismissedContributionPrompts.contains(identifier)
    }

    func resetBetaSafetyConfirmation() {
        hasAcknowledgedRevealSafety = false
    }

    func selectLanguage(_ preference: LanguagePreference) {
        languagePreferenceStore.setPreference(preference)
        languagePreference = preference
    }

    var locale: Locale {
        let identifier = languagePreference.localeIdentifier
            ?? Locale.preferredLanguages.first
            ?? "en-AU"
        return Locale(identifier: identifier)
    }

    var preferredColorScheme: ColorScheme? {
        switch appearancePreference {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    func refreshRoleContext() async {
        guard authenticationState.isSignedIn else {
            roleContext = .guest
            isRoleContextConfirmed = true
            sessionError = nil
            return
        }
        do {
            roleContext = try await roleRepository.sessionRoleContext()
            isRoleContextConfirmed = true
            sessionError = nil
        } catch let error as RepositoryError {
            roleContext = .guest
            isRoleContextConfirmed = false
            sessionError = error
        } catch {
            roleContext = .guest
            isRoleContextConfirmed = false
            sessionError = .unknown
        }
    }
}
