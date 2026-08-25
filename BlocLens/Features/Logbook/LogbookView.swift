import SwiftUI

struct LogbookView: View {
    let environment: AppEnvironment

    @StateObject private var viewModel: LogbookViewModel

    init(environment: AppEnvironment) {
        self.environment = environment
        _viewModel = StateObject(wrappedValue: LogbookViewModel(environment: environment))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(L10n.Logbook.title)
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
                        HStack {
                            Text(verbatim: grade.displayName)
                            Spacer()
                            Text(data.statistics.gradeDistribution[grade, default: 0], format: .number)
                                .foregroundStyle(DesignColour.secondaryText)
                        }
                    }
                }
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
                ForEach(data.recentRecords) { item in
                    recordRow(item)
                }
            }
        }
        .accessibilityIdentifier("logbook-dashboard")
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
