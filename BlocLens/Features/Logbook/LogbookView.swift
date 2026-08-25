import SwiftUI

struct LogbookView: View {
    let environment: AppEnvironment
    @ObservedObject var session: AppSession

    @StateObject private var viewModel: LogbookViewModel

    init(environment: AppEnvironment, session: AppSession) {
        self.environment = environment
        self.session = session
        _viewModel = StateObject(wrappedValue: LogbookViewModel(environment: environment))
    }

    var body: some View {
        NavigationStack {
            Group {
                if session.authenticationState.isSignedIn {
                    content
                } else {
                    signedOutState
                }
            }
                .navigationTitle(L10n.Logbook.title)
                .navigationDestination(for: ClimbingRoute.self) { route in
                    RouteDetailView(route: route, environment: environment, session: session)
                }
        }
        .onAppear { Task { await viewModel.load() } }
        .onChange(of: session.authenticationState) { _, state in
            if state.isSignedIn { Task { await viewModel.load() } }
        }
    }

    private var signedOutState: some View {
        VStack(spacing: DesignSpacing.large) {
            EmptyStateView(
                title: L10n.Logbook.signInTitle,
                message: L10n.Logbook.signInMessage,
                systemImage: "lock.fill"
            )
            Button(L10n.Authentication.signIn) {
                _ = session.requireAuthentication(for: .account)
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, DesignSpacing.large)
        }
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
                title: L10n.Logbook.emptyTitle,
                message: L10n.Logbook.emptyMessage,
                systemImage: "book.closed"
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

    private func dashboard(data: LogbookDashboardData, isOffline: Bool) -> some View {
        List {
            if isOffline {
                Section {
                    Label(L10n.State.offlineCachedMessage, systemImage: "wifi.slash")
                        .foregroundStyle(DesignColour.warning)
                }
            }

            Section(L10n.Logbook.statistics) {
                statisticRow(L10n.Logbook.climbingCount, value: "\(data.statistics.climbingCount)")
                statisticRow(L10n.Logbook.sentCount, value: "\(data.statistics.sentCount)")
                statisticRow(L10n.Logbook.flashCount, value: "\(data.statistics.flashCount)")
                statisticRow(
                    L10n.Logbook.highestGrade,
                    value: data.statistics.highestGrade?.displayName ?? String(localized: L10n.Grade.unknown)
                )
                if !data.statistics.gradeDistribution.isEmpty {
                    ForEach(data.statistics.gradeDistribution.keys.sorted(), id: \.self) { grade in
                        gradeDistributionRow(
                            grade: grade,
                            count: data.statistics.gradeDistribution[grade, default: 0],
                            maximum: data.statistics.gradeDistribution.values.max() ?? 1
                        )
                    }
                }
            }

            Section(L10n.Logbook.filters) {
                Picker(L10n.Logbook.statusFilter, selection: $viewModel.statusFilter) {
                    Text(L10n.Common.all).tag(LogbookStatus?.none)
                    ForEach(LogbookStatus.allCases, id: \.self) { status in
                        Text(L10n.logbookStatus(status)).tag(Optional(status))
                    }
                }
                Toggle(L10n.Logbook.lastThirtyDays, isOn: $viewModel.recentOnly)
            }

            Section(L10n.Logbook.projects) {
                if data.projects.isEmpty {
                    Text(L10n.Home.noProjects)
                        .foregroundStyle(DesignColour.secondaryText)
                } else {
                    ForEach(data.projects) { item in
                        recordRow(item)
                    }
                }
            }

            Section(L10n.Logbook.recentRecords) {
                let filtered = viewModel.filteredRecords(from: data)
                if filtered.isEmpty {
                    Text(L10n.Logbook.noMatchingRecords)
                        .foregroundStyle(DesignColour.secondaryText)
                } else {
                    ForEach(filtered) { item in
                        NavigationLink(value: item.route) { recordRow(item) }
                    }
                }
            }
        }
        .accessibilityIdentifier("logbook-dashboard")
    }

    private func gradeDistributionRow(grade: VGrade, count: Int, maximum: Int) -> some View {
        VStack(alignment: .leading, spacing: DesignSpacing.xSmall) {
            HStack {
                Text(verbatim: grade.displayName)
                Spacer()
                Text(count, format: .number)
            }
            GeometryReader { proxy in
                Capsule()
                    .fill(DesignColour.surface)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(DesignColour.opticBlue)
                            .frame(width: proxy.size.width * CGFloat(count) / CGFloat(max(maximum, 1)))
                    }
            }
            .frame(height: 8)
        }
        .accessibilityElement(children: .combine)
    }

    private func statisticRow(_ label: LocalizedStringResource, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(DesignColour.secondaryText)
        }
    }

    private func recordRow(_ item: LogbookRecordItem) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(item.route.colourOrTag).font(.headline)
                Text(item.route.officialGrade?.displayName ?? String(localized: L10n.Grade.unknown))
                    .font(.caption)
                    .foregroundStyle(DesignColour.secondaryText)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(L10n.logbookStatus(item.entry.status))
                    .font(.caption.bold())
                    .foregroundStyle(DesignColour.opticBlue)
                if item.entry.syncState == .queued {
                    Text(L10n.Logbook.queued)
                        .font(.caption2)
                        .foregroundStyle(DesignColour.warning)
                }
            }
        }
    }
}

#Preview("Logbook — Signed In") {
    let environment = AppEnvironment.development(authenticationState: .signedIn(DevelopmentFixtures.mockProfile))
    let session = AppSession(environment: environment)
    LogbookView(environment: environment, session: session)
        .task { await session.load() }
}

#Preview("Logbook — Empty") {
    let environment = AppEnvironment.development(scenario: .empty, authenticationState: .signedIn(DevelopmentFixtures.mockProfile))
    let session = AppSession(environment: environment)
    LogbookView(environment: environment, session: session)
        .task { await session.load() }
}
