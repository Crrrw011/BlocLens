import SwiftUI

struct HomeView: View {
    let environment: AppEnvironment

    @StateObject private var viewModel: HomeViewModel
    @State private var showsContributionPrompt = true

    init(environment: AppEnvironment) {
        self.environment = environment
        _viewModel = StateObject(wrappedValue: HomeViewModel(environment: environment))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(L10n.Home.title)
        }
        .onAppear { Task { await viewModel.load() } }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .initial, .loading:
            LoadingStateView()
        case .loaded(let data):
            dashboard(data: data, isOffline: false)
        case .offlineWithCache(let data):
            dashboard(data: data, isOffline: true)
        case .empty:
            EmptyStateView(
                title: L10n.Home.emptyTitle,
                message: L10n.Home.emptyMessage,
                systemImage: "house"
            )
        case .error:
            ErrorStateView(message: L10n.State.fixtureErrorMessage) {
                Task { await viewModel.load() }
            }
        case .offlineWithoutCache:
            EmptyStateView(
                title: L10n.State.offlineTitle,
                message: L10n.State.offlineNoCacheMessage,
                systemImage: "wifi.slash"
            )
        }
    }

    private func dashboard(data: HomeDashboardData, isOffline: Bool) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSpacing.large) {
                if isOffline {
                    Label(L10n.State.offlineCachedMessage, systemImage: "wifi.slash")
                        .font(.caption)
                        .foregroundStyle(DesignColour.warning)
                }

                dashboardSection(L10n.Home.currentGym) {
                    if let gym = data.frequentGym {
                        VStack(alignment: .leading) {
                            Text(gym.name).font(.headline)
                            Text(gym.suburb).foregroundStyle(DesignColour.secondaryText)
                        }
                    } else {
                        Text(L10n.Home.noFrequentGym)
                    }
                }

                dashboardSection(L10n.Home.activeProjects) {
                    if data.projects.isEmpty {
                        Text(L10n.Home.noProjects).foregroundStyle(DesignColour.secondaryText)
                    } else {
                        ForEach(data.projects) { item in
                            recordRow(item.entry, route: item.route)
                        }
                    }
                }
                .accessibilityIdentifier("home-projects-section")

                dashboardSection(L10n.Home.latestResets) {
                    ForEach(data.resets) { item in
                        HStack {
                            Text(item.gym.name)
                            Spacer()
                            Text(item.date.formatted(date: .abbreviated, time: .omitted))
                                .foregroundStyle(DesignColour.secondaryText)
                        }
                    }
                }

                dashboardSection(L10n.Home.recentRecords) {
                    ForEach(data.recentRecords) { item in
                        recordRow(item.entry, route: item.route)
                    }
                }

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
            .padding()
        }
        .background(DesignColour.background)
    }

    private func dashboardSection<Content: View>(
        _ title: LocalizedStringResource,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignSpacing.small) {
            Text(title).font(.title3.bold())
            content()
        }
        .cardStyle()
    }

    private func recordRow(_ entry: LogbookEntry, route: ClimbingRoute) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(route.colourOrTag).font(.headline)
                Text(route.officialGrade?.displayName ?? String(localized: L10n.Grade.unknown))
                    .font(.caption)
                    .foregroundStyle(DesignColour.secondaryText)
            }
            Spacer()
            Text(L10n.logbookStatus(entry.status))
                .font(.caption.bold())
                .foregroundStyle(DesignColour.opticBlue)
        }
    }
}

#Preview("Home — Light") {
    HomeView(environment: .development())
        .preferredColorScheme(.light)
}

#Preview("Home — Dark") {
    HomeView(environment: .development())
        .preferredColorScheme(.dark)
}
