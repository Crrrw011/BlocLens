import SwiftUI

struct WallZoneRouteListView: View {
    let wallZone: WallZone
    let environment: AppEnvironment

    @StateObject private var viewModel: WallZoneRouteListViewModel

    init(wallZone: WallZone, environment: AppEnvironment) {
        self.wallZone = wallZone
        self.environment = environment
        _viewModel = StateObject(
            wrappedValue: WallZoneRouteListViewModel(
                wallZone: wallZone,
                repository: environment.routeRepository,
                logbookRepository: environment.logbookRepository,
                userID: environment.currentUserID
            )
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            zoneHeader
            filterBar
            routeContent
        }
        .navigationTitle(wallZone.name)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $viewModel.filter.query, prompt: Text(L10n.Search.routePrompt))
        .onSubmit(of: .search) { Task { await viewModel.load() } }
        .onChange(of: viewModel.filter.gradeBand) { _, _ in Task { await viewModel.load() } }
        .onChange(of: viewModel.filter.includesArchived) { _, _ in Task { await viewModel.load() } }
        .task { await viewModel.load() }
    }

    private var zoneHeader: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.xSmall) {
            Text(wallZone.locationDescription)
            HStack {
                Label(L10n.wallType(wallZone.wallType), systemImage: "angle")
                if let reset = wallZone.latestResetDate {
                    Label(reset.formatted(date: .abbreviated, time: .omitted), systemImage: "arrow.clockwise")
                }
            }
            .font(.caption)
            .foregroundStyle(DesignColour.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(DesignColour.surface)
    }

    private var filterBar: some View {
        HStack {
            Picker(L10n.Filter.grade, selection: $viewModel.filter.gradeBand) {
                ForEach(GradeBand.allCases, id: \.self) { band in
                    Text(L10n.gradeBand(band)).tag(band)
                }
            }
            .pickerStyle(.menu)
            Toggle(L10n.Filter.showHistory, isOn: $viewModel.filter.includesArchived)
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var routeContent: some View {
        switch viewModel.state {
        case .initial, .loading:
            LoadingStateView().frame(maxHeight: .infinity)
        case .loaded(let routes), .offlineWithCache(let routes):
            List(routes) { route in
                NavigationLink(value: route) {
                    RouteRow(route: route, status: viewModel.statusByRouteID[route.id])
                }
                .accessibilityIdentifier("route-row-\(route.id.rawValue)")
            }
            .listStyle(.plain)
        case .empty:
            EmptyStateView(
                title: L10n.RouteList.emptyTitle,
                message: L10n.RouteList.emptyMessage,
                systemImage: "line.3.horizontal.decrease.circle"
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
}

private struct RouteRow: View {
    let route: ClimbingRoute
    let status: LogbookStatus?

    var body: some View {
        HStack {
            Circle()
                .fill(DesignColour.surface)
                .overlay(Text(String(route.colourOrTag.prefix(1))).font(.caption.bold()))
                .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: DesignSpacing.xSmall) {
                HStack {
                    Text(route.colourOrTag).font(.headline)
                    if route.lifecycle == .archived {
                        Text(L10n.Route.archived)
                            .font(.caption)
                            .foregroundStyle(DesignColour.warning)
                    }
                }
                HStack {
                    Text(route.officialGrade?.displayName ?? String(localized: L10n.Grade.unknown))
                    if let community = route.communityGradeSummary.displayGrade {
                        Text(L10n.Route.communityShortLabel) + Text(verbatim: " \(community.displayName)")
                    }
                    Label("\(route.betaCount)", systemImage: "link")
                }
                .font(.caption)
                .foregroundStyle(DesignColour.secondaryText)
                if let status {
                    Text(L10n.logbookStatus(status))
                        .font(.caption.bold())
                        .foregroundStyle(DesignColour.opticBlue)
                }
            }
        }
        .padding(.vertical, DesignSpacing.xSmall)
    }
}
