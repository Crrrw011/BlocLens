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
        if arguments.contains("--cloud-supabase") {
            environment = .cloudSupabase(configuration: Self.requiredCloudConfiguration())
        } else if arguments.contains("--local-supabase") {
            environment = .localSupabase(configuration: Self.requiredLocalConfiguration())
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

    #if DEBUG
    private static func requiredLocalConfiguration() -> RemoteConfiguration {
        do {
            guard let configuration = try LocalEnvironmentConfiguration.make() else {
                preconditionFailure("--local-supabase requires BLOCLENS_SUPABASE_URL and BLOCLENS_SUPABASE_ANON_KEY.")
            }
            return configuration
        } catch {
            preconditionFailure("Invalid local Supabase configuration: \(error)")
        }
    }

    private static func requiredCloudConfiguration() -> RemoteConfiguration {
        do {
            guard let configuration = try LocalEnvironmentConfiguration.makeCloud() else {
                preconditionFailure("--cloud-supabase requires BLOCLENS_CLOUD_URL and BLOCLENS_CLOUD_ANON_KEY.")
            }
            return configuration
        } catch {
            preconditionFailure("Invalid Cloud Supabase configuration: \(error)")
        }
    }
    #endif
}
