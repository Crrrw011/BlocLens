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
        if arguments.contains("--mock-empty") {
            environment = .development(scenario: .empty, authenticationState: authenticationState, onboardingStore: onboardingStore)
        } else if arguments.contains("--mock-error") {
            environment = .development(scenario: .error, authenticationState: authenticationState, onboardingStore: onboardingStore)
        } else if arguments.contains("--mock-offline-no-cache") {
            environment = .development(scenario: .offlineWithoutCache, isOnline: false, authenticationState: authenticationState, onboardingStore: onboardingStore)
        } else if arguments.contains("--mock-offline-cached") {
            environment = .development(scenario: .offlineWithCache, isOnline: false, authenticationState: authenticationState, onboardingStore: onboardingStore)
        } else {
            environment = .development(authenticationState: authenticationState, onboardingStore: onboardingStore)
        }
        #else
        environment = .development()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(environment: environment)
        }
    }
}
