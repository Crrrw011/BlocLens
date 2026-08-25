import SwiftUI

struct HomeView: View {
    let environment: AppEnvironment
    @ObservedObject var session: AppSession
    @StateObject private var viewModel: HomeViewModel

    init(environment: AppEnvironment, session: AppSession) {
        self.environment = environment
        self.session = session
        _viewModel = StateObject(wrappedValue: HomeViewModel(environment: environment))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(L10n.Home.title)
                .navigationDestination(for: Gym.self) { GymDetailView(gym: $0, environment: environment, session: session) }
                .navigationDestination(for: WallZone.self) { WallZoneRouteListView(wallZone: $0, environment: environment, session: session) }
                .navigationDestination(for: ClimbingRoute.self) { RouteDetailView(route: $0, environment: environment, session: session) }
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
            EmptyStateView(title: L10n.Home.emptyTitle, message: L10n.Home.emptyMessage, systemImage: "house")
        case .error:
            ErrorStateView(message: L10n.State.fixtureErrorMessage) { Task { await viewModel.load() } }
        case .offlineWithoutCache:
            OfflineStateView(hasCachedData: false)
        }
    }

    private func dashboard(data: HomeDashboardData, isOffline: Bool) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignSpacing.large) {
                if isOffline { OfflineBanner(message: L10n.State.offlineCachedMessage) }

                homeSection(title: L10n.Home.currentGym) {
                    if let gym = data.frequentGym {
                        NavigationLink(value: gym) { GymSummaryCard(gym: gym) }
                            .buttonStyle(.plain)
                    } else {
                        compactEmpty(message: L10n.Home.noFrequentGym, systemImage: "mappin.slash")
                    }
                }

                homeSection(title: L10n.Home.activeProjects, supporting: L10n.Home.projectsSupporting) {
                    privateContent {
                        if data.projects.isEmpty {
                            compactEmpty(message: L10n.Home.noProjects, systemImage: "hammer")
                        } else {
                            VStack(spacing: DesignSpacing.small) {
                                ForEach(data.projects) { item in
                                    NavigationLink(value: item.route) { projectRow(item) }
                                        .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .accessibilityIdentifier("home-projects-section")

                homeSection(title: L10n.Home.latestResets) {
                    VStack(spacing: DesignSpacing.small) {
                        ForEach(data.resets) { item in
                            NavigationLink(value: item.gym) { resetRow(item) }
                                .buttonStyle(.plain)
                        }
                    }
                }

                homeSection(title: L10n.Home.recentRecords) {
                    privateContent {
                        VStack(spacing: DesignSpacing.small) {
                            ForEach(data.recentRecords) { item in
                                NavigationLink(value: item.route) { recentRecordRow(item) }
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                }

                if session.isContributionPromptVisible("home-route-accuracy") {
                    ContributionPromptView(
                        title: L10n.Home.contributionTitle,
                        message: L10n.Home.contributionMessage,
                        primaryActionTitle: L10n.Home.contributionAction,
                        primaryAction: { _ = session.requireAuthentication(for: .account) },
                        dismissAction: { session.dismissContributionPrompt("home-route-accuracy") }
                    )
                }
            }
            .padding(.horizontal, DesignSpacing.medium)
            .padding(.vertical, DesignSpacing.small)
        }
        .background(DesignColour.backgroundSecondary)
    }

    private func homeSection<Content: View>(
        title: LocalizedStringResource,
        supporting: LocalizedStringResource? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignSpacing.compact) {
            SectionHeader(title: title, supportingText: supporting)
            content()
        }
    }

    @ViewBuilder
    private func privateContent<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if session.authenticationState.isSignedIn {
            content()
        } else {
            VStack(alignment: .leading, spacing: DesignSpacing.small) {
                Label(L10n.Home.privateLogbookMessage, systemImage: "lock.fill")
                    .font(DesignTypography.supporting)
                    .foregroundStyle(DesignColour.textSecondary)
                Button(L10n.Home.privateLogbookAction) { _ = session.requireAuthentication(for: .account) }
                    .buttonStyle(CompactActionButtonStyle())
            }
            .cardStyle()
        }
    }

    private func projectRow(_ item: HomeProjectItem) -> some View {
        HStack(alignment: .top, spacing: DesignSpacing.compact) {
            RouteColourSwatch(colourOrTag: item.route.colourOrTag, size: 46)
            VStack(alignment: .leading, spacing: DesignSpacing.xSmall) {
                HStack {
                    Text(item.route.colourOrTag).font(DesignTypography.cardTitle)
                    Spacer()
                    Text(item.route.officialGrade?.displayName ?? String(localized: L10n.Grade.unknown))
                        .font(DesignTypography.gradeEmphasis)
                }
                Text("\(item.gym.name) · \(item.wallZone.name)")
                    .font(DesignTypography.supporting)
                    .foregroundStyle(DesignColour.textSecondary)
                if let archiveDate = item.route.expectedArchiveDate {
                    Label {
                        Text(L10n.Route.estimatedArchive) + Text(verbatim: " \(archiveDate.formatted(date: .abbreviated, time: .omitted))")
                    } icon: {
                        Image(systemName: "calendar.badge.exclamationmark")
                    }
                    .font(DesignTypography.caption)
                    .foregroundStyle(DesignColour.warning)
                }
            }
        }
        .cardStyle(elevated: true)
        .accessibilityElement(children: .combine)
    }

    private func resetRow(_ item: HomeResetItem) -> some View {
        HStack(spacing: DesignSpacing.compact) {
            Image(systemName: "arrow.clockwise")
                .foregroundStyle(DesignColour.brandPrimary)
                .frame(width: 36, height: 36)
                .background(DesignColour.brandTint, in: RoundedRectangle(cornerRadius: DesignRadius.control))
            VStack(alignment: .leading, spacing: DesignSpacing.xSmall) {
                Text(item.gym.name).font(DesignTypography.cardTitle)
                if let zone = item.wallZone {
                    Text(zone.name).font(DesignTypography.caption).foregroundStyle(DesignColour.textSecondary)
                }
            }
            Spacer()
            Text(item.date.formatted(.relative(presentation: .named)))
                .font(DesignTypography.caption)
                .foregroundStyle(DesignColour.textSecondary)
        }
        .padding(DesignSpacing.compact)
        .background(DesignColour.surfacePrimary, in: RoundedRectangle(cornerRadius: DesignRadius.control))
        .accessibilityElement(children: .combine)
    }

    private func recentRecordRow(_ item: HomeRecordItem) -> some View {
        HStack(spacing: DesignSpacing.compact) {
            Image(systemName: statusIcon(item.entry.status))
                .foregroundStyle(DesignColour.brandPrimary)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: DesignSpacing.xSmall) {
                Text(item.route.colourOrTag).font(DesignTypography.cardTitle)
                Text("\(item.gym.name) · \(item.wallZone.name)")
                    .font(DesignTypography.caption)
                    .foregroundStyle(DesignColour.textSecondary)
            }
            Spacer()
            StatusChip(title: L10n.logbookStatus(item.entry.status), systemImage: statusIcon(item.entry.status), colour: DesignColour.brandPrimary)
        }
        .padding(.vertical, DesignSpacing.small)
        .accessibilityElement(children: .combine)
    }

    private func compactEmpty(message: LocalizedStringResource, systemImage: String) -> some View {
        Label(message, systemImage: systemImage)
            .font(DesignTypography.supporting)
            .foregroundStyle(DesignColour.textSecondary)
            .cardStyle()
    }

    private func statusIcon(_ status: LogbookStatus) -> String {
        switch status {
        case .wantToTry: "bookmark.fill"
        case .projecting: "hammer.fill"
        case .sent: "checkmark.circle.fill"
        case .flash: "bolt.fill"
        }
    }
}

#Preview("Home — Light") {
    let environment = AppEnvironment.development(authenticationState: .signedIn(DevelopmentFixtures.mockProfile))
    let session = AppSession(environment: environment)
    HomeView(environment: environment, session: session)
        .task { await session.load() }
        .preferredColorScheme(.light)
}

#Preview("Home — Dark") {
    let environment = AppEnvironment.development(authenticationState: .signedIn(DevelopmentFixtures.mockProfile))
    let session = AppSession(environment: environment)
    HomeView(environment: environment, session: session)
        .task { await session.load() }
        .preferredColorScheme(.dark)
}

#Preview("Home — Error") {
    let environment = AppEnvironment.development(scenario: .error)
    HomeView(environment: environment, session: AppSession(environment: environment))
}

#Preview("Home — Offline") {
    let environment = AppEnvironment.development(scenario: .offlineWithCache)
    HomeView(environment: environment, session: AppSession(environment: environment))
}
