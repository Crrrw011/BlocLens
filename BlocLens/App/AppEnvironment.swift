import Combine
import SwiftUI

struct AppEnvironment: Sendable {
    let gymRepository: any GymRepository
    let routeRepository: any RouteRepository
    let betaRepository: any BetaRepository
    let logbookRepository: any LogbookRepository
    let authenticationRepository: any AuthenticationRepository
    let onboardingStore: any OnboardingStore
    let languagePreferenceStore: any LanguagePreferenceStore
    let currentUserID: UserID
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
            authenticationRepository: MockAuthenticationRepository(initialState: authenticationState),
            onboardingStore: onboardingStore ?? InMemoryOnboardingStore(isComplete: isOnboardingComplete),
            languagePreferenceStore: languagePreferenceStore,
            currentUserID: DevelopmentFixtures.currentUserID,
            dataAvailability: scenario == .offlineWithCache ? .offlineCached : .online
        )
    }

    static func localSupabase(configuration: RemoteConfiguration) -> AppEnvironment {
        let client = SupabaseClientFactory.makeClient(configuration: configuration)
        let dataSource = SupabaseRemoteDataSource(client: client)
        return AppEnvironment(
            gymRepository: RemoteGymRepository(dataSource: dataSource),
            routeRepository: RemoteRouteRepository(dataSource: dataSource),
            betaRepository: MockBetaRepository(),
            logbookRepository: MockLogbookRepository(isOnline: true),
            authenticationRepository: MockAuthenticationRepository(initialState: .guest),
            onboardingStore: InMemoryOnboardingStore(isComplete: true),
            languagePreferenceStore: InMemoryLanguagePreferenceStore(),
            currentUserID: DevelopmentFixtures.currentUserID,
            dataAvailability: .online
        )
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

    private let authenticationRepository: any AuthenticationRepository
    private let onboardingStore: any OnboardingStore
    private let languagePreferenceStore: any LanguagePreferenceStore

    init(environment: AppEnvironment) {
        authenticationRepository = environment.authenticationRepository
        onboardingStore = environment.onboardingStore
        languagePreferenceStore = environment.languagePreferenceStore
        languagePreference = environment.languagePreferenceStore.preference()
    }

    func load() async {
        hasCompletedOnboarding = onboardingStore.isComplete()
        authenticationState = await authenticationRepository.state()
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
        let profile = await authenticationRepository.signInWithMockAccount()
        authenticationState = .signedIn(profile)
        resumedIntent = pendingIntent
        pendingIntent = nil
        isSignInGatePresented = false
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
        await authenticationRepository.signOut()
        authenticationState = .guest
        pendingIntent = nil
        resumedIntent = nil
        isSignInGatePresented = false
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
}
