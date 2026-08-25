import SwiftUI

struct ContributionPromptView: View {
    let title: LocalizedStringResource
    let message: LocalizedStringResource
    let primaryActionTitle: LocalizedStringResource
    let primaryAction: () -> Void
    let dismissAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.medium) {
            Label(title, systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(DesignColour.primaryText)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(DesignColour.secondaryText)

            Label(L10n.Contribution.privacyNote, systemImage: "lock")
                .font(.caption)
                .foregroundStyle(DesignColour.secondaryText)

            HStack(spacing: DesignSpacing.small) {
                Button(primaryActionTitle, action: primaryAction)
                    .buttonStyle(PrimaryButtonStyle())

                Button(L10n.Common.notNow, action: dismissAction)
                    .buttonStyle(CompactActionButtonStyle())
            }
        }
        .cardStyle()
        .accessibilityElement(children: .contain)
    }
}

#Preview("Contribution prompt — Light") {
    ContributionPromptView(
        title: L10n.Home.contributionTitle,
        message: L10n.Home.contributionMessage,
        primaryActionTitle: L10n.Home.contributionAction,
        primaryAction: {},
        dismissAction: {}
    )
    .padding()
    .preferredColorScheme(.light)
}

#Preview("Contribution prompt — Dark") {
    ContributionPromptView(
        title: L10n.Home.contributionTitle,
        message: L10n.Home.contributionMessage,
        primaryActionTitle: L10n.Home.contributionAction,
        primaryAction: {},
        dismissAction: {}
    )
    .padding()
    .preferredColorScheme(.dark)
}
