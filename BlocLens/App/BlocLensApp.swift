import SwiftUI

@main
struct BlocLensApp: App {
    private let environment: AppEnvironment

    init() {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        let onboardingStore: any OnboardingStore
        if arguments.contains("--reset-onboarding") {
            onboardingStore = InMemoryOnboardingStore(isComplete: false)
        } else if arguments.contains("--skip-onboarding") {
            onboardingStore = InMemoryOnboardingStore(isComplete: true)
        } else {
            onboardingStore = UserDefaultsOnboardingStore()
        }
        let authenticationState: AuthenticationState = arguments.contains("--mock-authenticated")
            ? .signedIn(DevelopmentFixtures.mockProfile)
            : .guest
        let languagePreferenceStore = UserDefaultsLanguagePreferenceStore()
        if arguments.contains("--local-supabase"),
           let localConfiguration = try? LocalEnvironmentConfiguration.make() {
            environment = .localSupabase(configuration: localConfiguration)
        } else if arguments.contains("--mock-empty") {
            environment = .development(scenario: .empty, authenticationState: authenticationState, onboardingStore: onboardingStore, languagePreferenceStore: languagePreferenceStore)
        } else if arguments.contains("--mock-error") {
            environment = .development(scenario: .error, authenticationState: authenticationState, onboardingStore: onboardingStore, languagePreferenceStore: languagePreferenceStore)
        } else if arguments.contains("--mock-offline-no-cache") {
            environment = .development(scenario: .offlineWithoutCache, isOnline: false, authenticationState: authenticationState, onboardingStore: onboardingStore, languagePreferenceStore: languagePreferenceStore)
        } else if arguments.contains("--mock-offline-cached") {
            environment = .development(scenario: .offlineWithCache, isOnline: false, authenticationState: authenticationState, onboardingStore: onboardingStore, languagePreferenceStore: languagePreferenceStore)
        } else {
            environment = .development(authenticationState: authenticationState, onboardingStore: onboardingStore, languagePreferenceStore: languagePreferenceStore)
        }
        #else
        environment = .development(languagePreferenceStore: UserDefaultsLanguagePreferenceStore())
        #endif
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(environment: environment)
        }
    }
}
