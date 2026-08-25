import SwiftUI

struct HomeView: View {
    @State private var showsContributionPrompt = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSpacing.large) {
                    Text(L10n.Home.title)
                        .pageTitleStyle()

                    VStack(alignment: .leading, spacing: DesignSpacing.small) {
                        Text(L10n.Home.cardTitle)
                            .font(.headline)
                        Text(L10n.Home.cardMessage)
                            .font(.subheadline)
                            .foregroundStyle(DesignColour.secondaryText)
                    }
                    .cardStyle()

                    if showsContributionPrompt {
                        ContributionPromptView(
                            title: L10n.Home.contributionTitle,
                            message: L10n.Home.contributionMessage,
                            primaryActionTitle: L10n.Home.contributionAction,
                            primaryAction: {},
                            dismissAction: { showsContributionPrompt = false }
                        )
                    }
                }
                .padding(DesignSpacing.medium)
            }
            .background(DesignColour.background)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

#Preview("Home — Light") {
    HomeView()
        .preferredColorScheme(.light)
}

#Preview("Home — Dark") {
    HomeView()
        .preferredColorScheme(.dark)
}
