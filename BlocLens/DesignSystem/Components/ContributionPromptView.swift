import SwiftUI

struct ContributionPromptView: View {
    let title: LocalizedStringResource
    let message: LocalizedStringResource
    let primaryActionTitle: LocalizedStringResource
    let primaryAction: () -> Void
    let dismissAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.medium) {
            Label(title, systemImage: "plus.circle")
                .font(DesignTypography.cardTitle)
                .foregroundStyle(DesignColour.textPrimary)

            Text(message)
                .font(DesignTypography.supporting)
                .foregroundStyle(DesignColour.textSecondary)

            Label(L10n.Contribution.privacyNote, systemImage: "lock")
                .font(.caption)
                .foregroundStyle(DesignColour.textSecondary)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: DesignSpacing.small) { actions }
                VStack(spacing: DesignSpacing.small) { actions }
            }
        }
        .padding(DesignSpacing.medium)
        .background(DesignColour.brandTint, in: RoundedRectangle(cornerRadius: DesignRadius.card, style: .continuous))
        .overlay(alignment: .leading) {
            Capsule()
                .fill(DesignColour.brandPrimary)
                .frame(width: 3)
                .padding(.vertical, DesignSpacing.medium)
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var actions: some View {
                Button(primaryActionTitle, action: primaryAction)
            .buttonStyle(SecondaryButtonStyle())

                Button(L10n.Common.notNow, action: dismissAction)
            .buttonStyle(QuietButtonStyle())
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
