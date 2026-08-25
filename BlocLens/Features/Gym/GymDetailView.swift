import SwiftUI

struct GymDetailView: View {
    let gym: Gym
    let environment: AppEnvironment

    @StateObject private var viewModel: GymDetailViewModel

    init(gym: Gym, environment: AppEnvironment) {
        self.gym = gym
        self.environment = environment
        _viewModel = StateObject(
            wrappedValue: GymDetailViewModel(gym: gym, repository: environment.gymRepository)
        )
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: DesignSpacing.small) {
                    HStack {
                        Text(gym.name).font(.title2.bold())
                        if gym.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(DesignColour.opticBlue)
                                .accessibilityLabel(L10n.Gym.verified)
                        }
                    }
                    Text("\(gym.suburb), \(gym.state)")
                        .foregroundStyle(DesignColour.secondaryText)
                    Label(L10n.Gym.developmentFixture, systemImage: "hammer")
                        .font(.caption)
                        .foregroundStyle(DesignColour.warning)
                }
            }

            Section(L10n.Gym.currentRoutesAndZones) {
                zonesContent
            }

            Section(L10n.Gym.latestReset) {
                if let date = gym.latestResetDate {
                    LabelValueRow(
                        label: L10n.Gym.resetDate,
                        value: date.formatted(date: .long, time: .omitted)
                    )
                    Text(L10n.Gym.fixtureResetNotice)
                        .font(.caption)
                        .foregroundStyle(DesignColour.secondaryText)
                } else {
                    Text(L10n.Gym.noResetData)
                        .foregroundStyle(DesignColour.secondaryText)
                }
            }

            Section(L10n.Gym.hardSoftIndex) {
                LabelValueRow(
                    label: L10n.Gym.overall,
                    value: String(localized: L10n.hardSoft(gym.overallHardSoftSummary))
                )
                ForEach([GradeBand.v0ToV2, .v3ToV5, .v6Plus], id: \.self) { band in
                    LabelValueRow(
                        label: L10n.gradeBand(band),
                        value: String(localized: L10n.Gym.fixtureBandSummary)
                    )
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
                ForEach(gym.facilities, id: \.self) { facility in
                    Label(L10n.facility(facility), systemImage: L10n.facilityIcon(facility))
                }
            }
        }
        .navigationTitle(L10n.Gym.detailTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }

    @ViewBuilder
    private var zonesContent: some View {
        switch viewModel.state {
        case .initial, .loading:
            LoadingStateView().frame(maxWidth: .infinity)
        case .loaded(let zones), .offlineWithCache(let zones):
            ForEach(zones) { zone in
                NavigationLink(value: zone) {
                    WallZoneRow(wallZone: zone)
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

private struct WallZoneRow: View {
    let wallZone: WallZone

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.xSmall) {
            HStack {
                Text(wallZone.name).font(.headline)
                Spacer()
                Text(L10n.wallAvailability(wallZone.availability))
                    .font(.caption)
                    .foregroundStyle(wallZone.availability == .active ? DesignColour.success : DesignColour.warning)
            }
            Text(wallZone.locationDescription)
                .font(.subheadline)
                .foregroundStyle(DesignColour.secondaryText)
            HStack {
                Label(L10n.wallType(wallZone.wallType), systemImage: "angle")
                Label("\(wallZone.routeCount)", systemImage: "circle.hexagongrid")
                Label("\(wallZone.betaCount)", systemImage: "link")
            }
            .font(.caption)
            if let date = wallZone.latestResetDate {
                Text(date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(DesignColour.secondaryText)
            }
        }
        .padding(.vertical, DesignSpacing.xSmall)
    }
}
