import SwiftUI

struct EmptyStateView: View {
    let title: LocalizedStringResource
    let message: LocalizedStringResource
    let systemImage: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        }
    }
}

struct LoadingStateView: View {
    var body: some View {
        VStack(spacing: DesignSpacing.medium) {
            ProgressView()
            Text(L10n.State.loading)
                .foregroundStyle(DesignColour.secondaryText)
        }
        .accessibilityElement(children: .combine)
    }
}

struct ErrorStateView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(L10n.State.errorTitle, systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button(L10n.Common.tryAgain, action: retry)
                .buttonStyle(.borderedProminent)
        }
    }
}

#Preview("Empty state — Light") {
    EmptyStateView(
        title: L10n.Logbook.emptyTitle,
        message: L10n.Logbook.emptyMessage,
        systemImage: "book.closed"
    )
    .preferredColorScheme(.light)
}

#Preview("Loading state — Dark") {
    LoadingStateView()
        .preferredColorScheme(.dark)
}

#Preview("Error state") {
    ErrorStateView(message: PreviewFixtures.sampleErrorMessage, retry: {})
}
