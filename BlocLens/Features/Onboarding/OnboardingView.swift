import SwiftUI

struct OnboardingView: View {
    let completion: () -> Void

    @State private var page = 0

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
        VStack(spacing: DesignSpacing.large) {
            HStack {
                Spacer()
                Button(L10n.Onboarding.skip, action: completion)
                    .buttonStyle(CompactActionButtonStyle())
                    .accessibilityIdentifier("onboarding-skip-button")
            }

            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    OnboardingPageView(page: pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            Button(page == pages.count - 1 ? L10n.Onboarding.exploreMap : L10n.Onboarding.continueButton) {
                if page == pages.count - 1 {
                    completion()
                } else {
                    withAnimation { page += 1 }
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityIdentifier(page == pages.count - 1 ? "onboarding-explore-map-button" : "onboarding-continue-button")
        }
        .padding(DesignSpacing.large)
        .background(DesignColour.background)
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
        VStack(spacing: DesignSpacing.large) {
            Spacer()
            ZStack {
                Circle()
                    .fill(DesignColour.opticBlue.opacity(0.12))
                    .frame(width: 180, height: 180)
                Image(systemName: page.systemImage)
                    .font(.system(size: 72))
                    .foregroundStyle(DesignColour.opticBlue)
            }
            Text(page.title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text(page.message)
                .font(.title3)
                .foregroundStyle(DesignColour.secondaryText)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .accessibilityElement(children: .combine)
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
