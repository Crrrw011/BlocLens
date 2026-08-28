import SwiftUI

struct AppShellView: View {
    let environment: AppEnvironment
    @ObservedObject var session: AppSession
    @State private var isAddMenuPresented = false
    @State private var selectedAddAction: AddAction?

    private var tabSelection: Binding<AppTab> {
        Binding(
            get: { session.selectedTab },
            set: { newTab in
                if newTab == .add {
                    isAddMenuPresented = true
                } else {
                    session.selectedTab = newTab
                }
            }
        )
    }

    var body: some View {
        TabView(selection: tabSelection) {
            HomeView(environment: environment, session: session)
                .tabItem { Label(AppTab.home.title, systemImage: AppTab.home.systemImage) }
                .tag(AppTab.home)

            MapView(environment: environment, session: session)
                .tabItem { Label(AppTab.map.title, systemImage: AppTab.map.systemImage) }
                .tag(AppTab.map)

            Color.clear
                .tabItem { Label(AppTab.add.title, systemImage: AppTab.add.systemImage) }
                .tag(AppTab.add)

            LogbookView(environment: environment, session: session)
                .tabItem { Label(AppTab.logbook.title, systemImage: AppTab.logbook.systemImage) }
                .tag(AppTab.logbook)

            ProfileView(environment: environment, session: session)
                .tabItem { Label(AppTab.profile.title, systemImage: AppTab.profile.systemImage) }
                .tag(AppTab.profile)
        }
        .tint(DesignColour.opticBlue)
        .confirmationDialog(
            L10n.Add.menuTitle,
            isPresented: $isAddMenuPresented,
            titleVisibility: .visible
        ) {
            ForEach(AddAction.menuCases) { action in
                Button {
                    if session.requireAuthentication(for: .add(action)) {
                        selectedAddAction = action
                    }
                } label: {
                    Label(action.title, systemImage: action.systemImage)
                }
            }
            Button(L10n.Common.cancel, role: .cancel) {}
        } message: {
            Text(L10n.Add.menuMessage)
        }
        .sheet(item: $selectedAddAction) { action in
            switch action {
            case .publishBetaLink:
                AddContributionView(action: action, environment: environment)
            case .recordCompletedRoute, .identifyOrMarkRoute:
                AddActionPlaceholderView(action: action)
            case .addNewRoute:
                EmptyView()
            }
        }
        .sheet(isPresented: $session.isSignInGatePresented) {
            SignInGateView(session: session)
        }
        .onChange(of: session.resumedIntent) { _, intent in
            guard case .add(let action) = intent else { return }
            selectedAddAction = action
            session.consumeResumedIntent(.add(action))
        }
        .sensoryFeedback(.selection, trigger: isAddMenuPresented)
    }
}

#Preview("Root — Light") {
    let environment = AppEnvironment.development(authenticationState: .signedIn(DevelopmentFixtures.mockProfile))
    let session = AppSession(environment: environment)
    AppShellView(environment: environment, session: session)
        .task { await session.load() }
        .preferredColorScheme(.light)
}

#Preview("Root — Dark") {
    let environment = AppEnvironment.development(authenticationState: .signedIn(DevelopmentFixtures.mockProfile))
    let session = AppSession(environment: environment)
    AppShellView(environment: environment, session: session)
        .task { await session.load() }
        .preferredColorScheme(.dark)
}
