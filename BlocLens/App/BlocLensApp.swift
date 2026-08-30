import SwiftUI

@main
struct BlocLensApp: App {
    private let environment: AppEnvironment

    init() {
        CrashReportingService.configure()
        let arguments = ProcessInfo.processInfo.arguments
        let onboardingStore: any OnboardingStore
        if arguments.contains("--reset-onboarding") {
            onboardingStore = InMemoryOnboardingStore(isComplete: false)
        } else if arguments.contains("--skip-onboarding") {
            onboardingStore = InMemoryOnboardingStore(isComplete: true)
        } else {
            onboardingStore = UserDefaultsOnboardingStore()
        }
        if arguments.contains("--reset-language") {
            UserDefaults.standard.removeObject(forKey: "bloclens.language.preference.v1")
        }
        let authenticationState: AuthenticationState = arguments.contains("--mock-authenticated")
            ? .signedIn(DevelopmentFixtures.mockProfile)
            : .guest
        let languagePreferenceStore = UserDefaultsLanguagePreferenceStore()

        let mode = DataSourceResolver.resolve(
            arguments: arguments,
            environment: ProcessInfo.processInfo.environment,
            infoDictionary: Bundle.main.infoDictionary ?? [:]
        )
        Self.logDataSource(mode)

        switch mode {
        case .mock(let reason):
            let scenario: MockRepositoryScenario
            if arguments.contains("--mock-empty") { scenario = .empty }
            else if arguments.contains("--mock-error") { scenario = .empty }
            else if reason.contains("error") { scenario = .error }
            else { scenario = .loaded }
            // Offline mock cases are handled as distinct modes, but .mock with offline reason falls here
            if arguments.contains("--mock-offline-cached") {
                environment = .development(scenario: .offlineWithCache, isOnline: false, authenticationState: authenticationState, onboardingStore: onboardingStore, languagePreferenceStore: languagePreferenceStore)
            } else if arguments.contains("--mock-offline-no-cache") {
                environment = .development(scenario: .offlineWithoutCache, isOnline: false, authenticationState: authenticationState, onboardingStore: onboardingStore, languagePreferenceStore: languagePreferenceStore)
            } else {
                environment = .development(scenario: scenario, authenticationState: authenticationState, onboardingStore: onboardingStore, languagePreferenceStore: languagePreferenceStore)
            }
        case .offlineWithCache:
            environment = .development(scenario: .offlineWithCache, isOnline: false, authenticationState: authenticationState, onboardingStore: onboardingStore, languagePreferenceStore: languagePreferenceStore)
        case .offlineWithoutCache:
            environment = .development(scenario: .offlineWithoutCache, isOnline: false, authenticationState: authenticationState, onboardingStore: onboardingStore, languagePreferenceStore: languagePreferenceStore)
        case .supabase(let configuration, _):
            if arguments.contains("--ephemeral-auth-storage"), configuration.mode == .localDevelopment {
                let client = SupabaseClientFactory.makeClient(configuration: configuration, authStorage: InMemoryAuthLocalStorage())
                environment = .localSupabase(configuration: configuration, client: client)
            } else if configuration.mode == .production {
                environment = .cloudSupabase(configuration: configuration)
            } else {
                environment = .localSupabase(configuration: configuration)
            }
        case .error(let reason):
            #if DEBUG
            if arguments.contains("--cloud-supabase") || arguments.contains("--local-supabase") {
                preconditionFailure(reason)
            }
            // Debug without config and without explicit mock: diagnostic Mock (not silent)
            environment = .development(authenticationState: authenticationState, onboardingStore: onboardingStore, languagePreferenceStore: languagePreferenceStore)
            #else
            // Release must not masquerade as Mock — fail fast with diagnostic
            preconditionFailure("Release misconfiguration: \(reason)")
            #endif
        }
    }

    private static func logDataSource(_ mode: DataSourceMode) {
        // Never log keys — only mode, reason, and host
        let redacted: String
        switch mode {
        case .mock(let r): redacted = "Mock (\(r))"
        case .supabase(let c, let r): redacted = "Supabase \(c.mode) host=\(c.projectURL.host ?? "unknown") (\(r))"
        case .offlineWithCache: redacted = "OfflineWithCache"
        case .offlineWithoutCache: redacted = "OfflineWithoutCache"
        case .error(let r): redacted = "Error (\(r))"
        }
        print("[BlocLens] DataSource: \(redacted)")
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
