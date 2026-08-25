import SwiftUI

struct AppShellView: View {
    @State private var selectedTab = AppTab.defaultSelected
    @State private var isAddMenuPresented = false
    @State private var selectedAddAction: AddAction?

    private var tabSelection: Binding<AppTab> {
        Binding(
            get: { selectedTab },
            set: { newTab in
                if newTab == .add {
                    isAddMenuPresented = true
                } else {
                    selectedTab = newTab
                }
            }
        )
    }

    var body: some View {
        TabView(selection: tabSelection) {
            HomeView()
                .tabItem { Label(AppTab.home.title, systemImage: AppTab.home.systemImage) }
                .tag(AppTab.home)

            MapPlaceholderView()
                .tabItem { Label(AppTab.map.title, systemImage: AppTab.map.systemImage) }
                .tag(AppTab.map)

            Color.clear
                .tabItem { Label(AppTab.add.title, systemImage: AppTab.add.systemImage) }
                .tag(AppTab.add)

            LogbookView()
                .tabItem { Label(AppTab.logbook.title, systemImage: AppTab.logbook.systemImage) }
                .tag(AppTab.logbook)

            ProfileView()
                .tabItem { Label(AppTab.profile.title, systemImage: AppTab.profile.systemImage) }
                .tag(AppTab.profile)
        }
        .tint(DesignColour.opticBlue)
        .confirmationDialog(
            L10n.Add.menuTitle,
            isPresented: $isAddMenuPresented,
            titleVisibility: .visible
        ) {
            ForEach(AddAction.allCases) { action in
                Button(action.title) {
                    selectedAddAction = action
                }
            }
            Button(L10n.Common.cancel, role: .cancel) {}
        } message: {
            Text(L10n.Add.menuMessage)
        }
        .sheet(item: $selectedAddAction) { action in
            AddActionPlaceholderView(action: action)
        }
    }
}

#Preview("Root — Light") {
    AppShellView()
        .preferredColorScheme(.light)
}

#Preview("Root — Dark") {
    AppShellView()
        .preferredColorScheme(.dark)
}
