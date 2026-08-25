import SwiftUI

struct ProfileView: View {
    var body: some View {
        NavigationStack {
            EmptyStateView(
                title: L10n.Profile.emptyTitle,
                message: L10n.Profile.emptyMessage,
                systemImage: "person.crop.circle"
            )
            .navigationTitle(L10n.Profile.title)
        }
    }
}
