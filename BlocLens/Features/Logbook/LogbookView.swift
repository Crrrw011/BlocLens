import SwiftUI

struct LogbookView: View {
    var body: some View {
        NavigationStack {
            EmptyStateView(
                title: L10n.Logbook.emptyTitle,
                message: L10n.Logbook.emptyMessage,
                systemImage: "book.closed"
            )
            .navigationTitle(L10n.Logbook.title)
        }
    }
}
