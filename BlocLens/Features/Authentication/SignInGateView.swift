import SwiftUI

struct SignInGateView: View {
    @ObservedObject var session: AppSession

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: DesignSpacing.large) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 54))
                    .foregroundStyle(DesignColour.opticBlue)

                Text(L10n.Authentication.gateTitle)
                    .font(.largeTitle.bold())
                Text(reason)
                    .foregroundStyle(DesignColour.secondaryText)

                VStack(spacing: DesignSpacing.small) {
                    Button(L10n.Authentication.apple) {}
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(true)
                        .accessibilityHint(L10n.Authentication.providerUnavailableHint)

                    Button(L10n.Authentication.google) {}
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(true)
                        .accessibilityHint(L10n.Authentication.providerUnavailableHint)

                    #if DEBUG
                    Button(L10n.Authentication.mockAccount) {
                        Task { await session.signInWithMockAccount() }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier("mock-sign-in-button")
                    #endif
                }

                Text(L10n.Authentication.mockNotice)
                    .font(.caption)
                    .foregroundStyle(DesignColour.tertiaryText)

                Button(L10n.Common.notNow) { session.cancelSignIn() }
                    .buttonStyle(CompactActionButtonStyle())
                    .accessibilityIdentifier("sign-in-not-now-button")
            }
            .padding(DesignSpacing.large)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(DesignColour.background)
            .navigationTitle(L10n.Authentication.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled()
    }

    private var reason: LocalizedStringResource {
        switch session.pendingIntent {
        case .revealBeta: L10n.Authentication.revealReason
        case .saveLogbook: L10n.Authentication.logbookReason
        case .add: L10n.Authentication.contributionReason
        case .helpful: L10n.Authentication.helpfulReason
        case .account, .none: L10n.Authentication.accountReason
        }
    }
}
