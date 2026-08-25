import SwiftUI

struct OnboardingView: View {
    let completion: () -> Void

    @State private var page = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: L10n.Onboarding.findGymsTitle,
            message: L10n.Onboarding.findGymsMessage,
            systemImage: "map.fill"
        ),
        OnboardingPage(
            title: L10n.Onboarding.findBetaTitle,
            message: L10n.Onboarding.findBetaMessage,
            systemImage: "eye.circle.fill"
        ),
        OnboardingPage(
            title: L10n.Onboarding.trackTitle,
            message: L10n.Onboarding.trackMessage,
            systemImage: "book.closed.fill"
        )
    ]

    var body: some View {
        VStack(spacing: DesignSpacing.medium) {
            HStack {
                Label(L10n.Brand.name, systemImage: "camera.aperture")
                    .font(.headline)
                    .foregroundStyle(DesignColour.textPrimary)
                Spacer()
                Button(L10n.Onboarding.skip, action: completion)
                    .buttonStyle(QuietButtonStyle())
                    .accessibilityIdentifier("onboarding-skip-button")
            }

            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    OnboardingPageView(page: pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: DesignSpacing.small) {
                ForEach(pages.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? DesignColour.brandPrimary : DesignColour.separator)
                        .frame(width: index == page ? 24 : 8, height: 8)
                }
            }
            .animation(DesignMotion.animation(DesignMotion.stateChange, reduceMotion: reduceMotion), value: page)
            .accessibilityHidden(true)

            Button(page == pages.count - 1 ? L10n.Onboarding.exploreMap : L10n.Onboarding.continueButton) {
                if page == pages.count - 1 {
                    completion()
                } else {
                    withAnimation(DesignMotion.animation(DesignMotion.stateChange, reduceMotion: reduceMotion)) { page += 1 }
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityIdentifier(page == pages.count - 1 ? "onboarding-explore-map-button" : "onboarding-continue-button")
        }
        .padding(.horizontal, DesignSpacing.large)
        .padding(.vertical, DesignSpacing.medium)
        .background(DesignColour.backgroundPrimary)
    }
}

private struct OnboardingPage: Identifiable {
    let id = UUID()
    let title: LocalizedStringResource
    let message: LocalizedStringResource
    let systemImage: String
}

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSpacing.large) {
                Spacer(minLength: DesignSpacing.large)
            ZStack {
                Circle()
                        .fill(DesignColour.brandTint)
                        .frame(width: 184, height: 184)
                    Circle()
                        .stroke(DesignColour.brandPrimary.opacity(0.18), lineWidth: 1)
                        .frame(width: 152, height: 152)
                Image(systemName: page.systemImage)
                        .font(.system(size: 64, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(DesignColour.brandPrimary)
            }
            Text(page.title)
                    .font(DesignTypography.largeScreenTitle)
                .multilineTextAlignment(.center)
            Text(page.message)
                    .font(DesignTypography.body)
                    .foregroundStyle(DesignColour.textSecondary)
                .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: 430)
                Text(L10n.Brand.tagline)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DesignColour.textTertiary)
                    .padding(.top, DesignSpacing.small)
                Spacer(minLength: DesignSpacing.large)
            }
            .frame(maxWidth: .infinity, minHeight: 480)
        }
    }
}

#Preview("Onboarding — Light") {
    OnboardingView(completion: {})
        .preferredColorScheme(.light)
}

#Preview("Onboarding — Dark") {
    OnboardingView(completion: {})
        .preferredColorScheme(.dark)
}
