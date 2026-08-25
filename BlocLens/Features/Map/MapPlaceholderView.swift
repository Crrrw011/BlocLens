import SwiftUI

struct MapPlaceholderView: View {
    var body: some View {
        NavigationStack {
            EmptyStateView(
                title: L10n.Map.emptyTitle,
                message: L10n.Map.emptyMessage,
                systemImage: "map"
            )
            .navigationTitle(L10n.Map.title)
        }
    }
}
