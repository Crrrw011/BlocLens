import SwiftUI

struct GymDetailView: View {
    let gym: Gym
    let environment: AppEnvironment
    @ObservedObject var session: AppSession

    @StateObject private var viewModel: GymDetailViewModel
    @State private var isFavourite = false
    @State private var isAddWallZonePresented = false

    init(gym: Gym, environment: AppEnvironment, session: AppSession) {
        self.gym = gym
        self.environment = environment
        self.session = session
        _viewModel = StateObject(
            wrappedValue: GymDetailViewModel(gym: gym, repository: environment.gymRepository)
        )
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: DesignSpacing.compact) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: DesignSpacing.xSmall) {
                            Text(gym.name).font(DesignTypography.navigationTitle)
                            Text("\(gym.suburb), \(gym.state)")
                                .font(DesignTypography.supporting)
                                .foregroundStyle(DesignColour.textSecondary)
                        }
                        if gym.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(DesignColour.brandPrimary)
                                .accessibilityLabel(L10n.Gym.verified)
                        }
                        Spacer()
                        Button { isFavourite.toggle() } label: {
                            Image(systemName: isFavourite ? "star.fill" : "star")
                        }
                        .buttonStyle(IconButtonStyle())
                        .accessibilityLabel(L10n.Profile.favouriteGym)
                        .accessibilityValue(isFavourite ? L10n.Common.selected : L10n.Common.notSelected)
                    }
                    Label(L10n.Gym.developmentFixture, systemImage: "hammer")
                        .font(.caption)
                        .foregroundStyle(DesignColour.warning)
                }
                .padding(.vertical, DesignSpacing.small)
            }

            Section(L10n.Gym.currentRoutesAndZones) {
                zonesContent
            }

            Section(L10n.Gym.latestReset) {
                if let date = gym.latestResetDate {
                    HStack(spacing: DesignSpacing.compact) {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .font(.title2)
                            .foregroundStyle(DesignColour.brandPrimary)
                        VStack(alignment: .leading, spacing: DesignSpacing.xSmall) {
                            Text(date.formatted(.relative(presentation: .named))).font(DesignTypography.cardTitle)
                            Text(date.formatted(date: .long, time: .omitted))
                                .font(DesignTypography.caption)
                                .foregroundStyle(DesignColour.textSecondary)
                        }
                    }
                    Text(L10n.Gym.fixtureResetNotice)
                        .font(.caption)
                        .foregroundStyle(DesignColour.secondaryText)
                } else {
                    Text(L10n.Gym.noResetData)
                        .foregroundStyle(DesignColour.secondaryText)
                }
            }

            Section(L10n.Gym.hardSoftIndex) {
                hardSoftRow(label: L10n.Gym.overall, value: L10n.hardSoft(gym.overallHardSoftSummary), emphasized: true)
                ForEach([GradeBand.v0ToV2, .v3ToV5, .v6Plus], id: \.self) { band in
                    hardSoftRow(label: L10n.gradeBand(band), value: L10n.Gym.fixtureBandSummary)
                }
                Text(L10n.Gym.communityEstimateNotice)
                    .font(.caption)
                    .foregroundStyle(DesignColour.secondaryText)
            }

            Section(L10n.Gym.operatingInformation) {
                Text(L10n.Gym.operatingFixtureMessage)
                    .foregroundStyle(DesignColour.secondaryText)
            }

            Section(L10n.Gym.facilities) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), alignment: .leading)], alignment: .leading, spacing: DesignSpacing.small) {
                    ForEach(gym.facilities, id: \.self) { facility in
                        FacilityChip(facility: facility)
                    }
                }
            }

            Section(L10n.Gym.contactDetails) {
                Text(L10n.Gym.contactFixtureMessage)
                    .foregroundStyle(DesignColour.secondaryText)
            }

            if session.isContributionPromptVisible("gym-\(gym.id.rawValue)") {
                Section {
                    ContributionPromptView(
                        title: L10n.Gym.contributionTitle,
                        message: L10n.Gym.contributionMessage,
                        primaryActionTitle: L10n.Home.contributionAction,
                        primaryAction: {
                            _ = session.requireAuthentication(for: .account)
                        },
                        dismissAction: {
                            session.dismissContributionPrompt("gym-\(gym.id.rawValue)")
                        }
                    )
                }
            }
        }
        .navigationTitle(L10n.Gym.detailTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    if session.requireAuthentication(for: .account) {
                        isAddWallZonePresented = true
                    }
                } label: {
                    Label(L10n.Gym.addWallZone, systemImage: "plus")
                }
                .accessibilityIdentifier("add-wall-zone-button")
            }
        }
        .sheet(isPresented: $isAddWallZonePresented) {
            AddWallZoneView(environment: environment, session: session, gym: gym)
        }
        .task { await viewModel.load() }
        .onAppear {
            isFavourite = session.authenticationState.profile?.favouriteGymID == gym.id
        }
    }

    @ViewBuilder
    private var zonesContent: some View {
        switch viewModel.state {
        case .initial, .loading:
            LoadingStateView().frame(maxWidth: .infinity)
        case .loaded(let zones), .offlineWithCache(let zones):
            ForEach(zones) { zone in
                NavigationLink(value: zone) {
                    WallZoneSummaryRow(wallZone: zone)
                }
                .accessibilityIdentifier("wall-zone-row-\(zone.id.rawValue)")
            }
        case .empty:
            EmptyStateView(
                title: L10n.WallZone.emptyTitle,
                message: L10n.WallZone.emptyMessage,
                systemImage: "square.stack.3d.up.slash"
            )
        case .error:
            ErrorStateView(message: L10n.State.fixtureErrorMessage) {
                Task { await viewModel.load() }
            }
        case .offlineWithoutCache:
            Text(L10n.State.offlineNoCacheMessage)
                .foregroundStyle(DesignColour.secondaryText)
        }
    }

    private func hardSoftRow(
        label: LocalizedStringResource,
        value: LocalizedStringResource,
        emphasized: Bool = false
    ) -> some View {
        HStack(spacing: DesignSpacing.compact) {
            Text(label).font(emphasized ? .headline : .subheadline.weight(.semibold))
            Spacer()
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(emphasized ? DesignColour.brandPrimary : DesignColour.textSecondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, DesignSpacing.xSmall)
        .accessibilityElement(children: .combine)
    }
}

private struct LabelValueRow: View {
    let label: LocalizedStringResource
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(DesignColour.secondaryText)
        }
    }
}

#Preview("Gym Detail — Loaded") {
    let environment = AppEnvironment.development()
    NavigationStack {
        GymDetailView(
            gym: DevelopmentFixtures.gyms[0],
            environment: environment,
            session: AppSession(environment: environment)
        )
    }
}

#Preview("Gym Detail — Empty") {
    let environment = AppEnvironment.development(scenario: .empty)
    NavigationStack {
        GymDetailView(
            gym: DevelopmentFixtures.gyms[0],
            environment: environment,
            session: AppSession(environment: environment)
        )
    }
}
