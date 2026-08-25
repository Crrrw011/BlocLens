import SwiftUI

struct AppRootView: View {
    let environment: AppEnvironment
    @StateObject private var session: AppSession

    init(environment: AppEnvironment) {
        self.environment = environment
        _session = StateObject(wrappedValue: AppSession(environment: environment))
    }

    var body: some View {
        Group {
            if !session.hasLoaded {
                LoadingStateView()
            } else if !session.hasCompletedOnboarding {
                OnboardingView { session.completeOnboarding() }
            } else {
                AppShellView(environment: environment, session: session)
            }
        }
        .id(session.languagePreference)
        .task { await session.load() }
        .environment(\.locale, session.locale)
        .preferredColorScheme(session.preferredColorScheme)
    }
}
