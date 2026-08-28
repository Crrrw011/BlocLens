import SwiftUI

struct WallZoneRouteListView: View {
    let wallZone: WallZone
    let environment: AppEnvironment
    @ObservedObject var session: AppSession

    @StateObject private var viewModel: WallZoneRouteListViewModel
    @State private var showsArchived = false
    @State private var isAddRoutePresented = false

    init(wallZone: WallZone, environment: AppEnvironment, session: AppSession) {
        self.wallZone = wallZone
        self.environment = environment
        self.session = session
        _viewModel = StateObject(
            wrappedValue: WallZoneRouteListViewModel(
                wallZone: wallZone,
                repository: environment.routeRepository,
                logbookRepository: environment.logbookRepository,
                userIDProvider: environment.currentUserID
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    if session.requireAuthentication(for: .add(.addNewRoute)) {
                        isAddRoutePresented = true
                    }
                } label: {
                    Label(L10n.Gym.addRouteInZone, systemImage: "plus")
                }
                .accessibilityIdentifier("add-route-in-zone-button")
            }
        }
        .sheet(isPresented: $isAddRoutePresented) {
            AddContributionView(action: .addNewRoute, environment: environment, preselectedWallZone: wallZone)
        }
        .searchable(text: $viewModel.options.query, prompt: Text(L10n.Search.routePrompt))
        .onSubmit(of: .search) { Task { await viewModel.load() } }
        .onChange(of: viewModel.options.query) { _, _ in Task { await viewModel.load() } }
        .onChange(of: viewModel.options.gradeBand) { _, _ in Task { await viewModel.load() } }
        .onChange(of: viewModel.options.hasBeta) { _, _ in Task { await viewModel.load() } }
        .onChange(of: viewModel.options.sort) { _, _ in Task { await viewModel.load() } }
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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSpacing.small) {
            if viewModel.options.activeFilterCount > 0 {
                StatusChip(
                    title: L10n.Filter.active,
                    systemImage: "line.3.horizontal.decrease.circle.fill",
                    colour: DesignColour.brandPrimary
                )
            }
            Picker(L10n.Filter.grade, selection: $viewModel.options.gradeBand) {
                ForEach(GradeBand.allCases, id: \.self) { band in
                    Text(L10n.gradeBand(band)).tag(band)
                }
            }
            .pickerStyle(.menu)
            Toggle(L10n.Filter.hasBeta, isOn: $viewModel.options.hasBeta)
                .toggleStyle(.button)
                .buttonStyle(CompactActionButtonStyle())
            Picker(L10n.Filter.sort, selection: $viewModel.options.sort) {
                ForEach(RouteSort.allCases, id: \.self) { sort in
                    Text(L10n.routeSort(sort)).tag(sort)
                }
            }
            .pickerStyle(.menu)
            }
        }
        .padding(.horizontal, DesignSpacing.medium)
        .padding(.vertical, DesignSpacing.small)
        .background(DesignColour.backgroundSecondary)
    }

    @ViewBuilder
    private var routeContent: some View {
        switch viewModel.state {
        case .initial, .loading:
            LoadingStateView().frame(maxHeight: .infinity)
        case .loaded(let routes), .offlineWithCache(let routes):
            List {
                Section(L10n.RouteList.currentRoutes) {
                    ForEach(routes) { route in
                        NavigationLink(value: route) {
                            RouteRow(route: route, status: visibleStatus(for: route))
                        }
                        .accessibilityIdentifier("route-row-\(route.id.rawValue)")
                    }
                }

                if !viewModel.archivedRoutes.isEmpty {
                    Section {
                        DisclosureGroup(L10n.RouteList.archivedRoutes, isExpanded: $showsArchived) {
                            ForEach(viewModel.archivedRoutes) { route in
                                NavigationLink(value: route) {
                                    RouteRow(route: route, status: visibleStatus(for: route))
                                }
                                .accessibilityIdentifier("route-row-\(route.id.rawValue)")
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        case .empty:
            VStack(spacing: DesignSpacing.medium) {
                EmptyStateView(
                    title: L10n.RouteList.emptyTitle,
                    message: L10n.RouteList.emptyMessage,
                    systemImage: "line.3.horizontal.decrease.circle"
                )
                if viewModel.options.hasActiveFilters {
                    Button(L10n.MapFilter.clear) { Task { await viewModel.clearFilters() } }
                        .buttonStyle(SecondaryButtonStyle())
                        .padding(.horizontal, DesignSpacing.large)
                }
            }
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

    private func visibleStatus(for route: ClimbingRoute) -> LogbookStatus? {
        session.authenticationState.isSignedIn ? viewModel.statusByRouteID[route.id] : nil
    }
}

private struct RouteRow: View {
    let route: ClimbingRoute
    let status: LogbookStatus?

    var body: some View {
        HStack(alignment: .top, spacing: DesignSpacing.compact) {
            RouteColourSwatch(colourOrTag: route.colourOrTag, size: 44)
            VStack(alignment: .leading, spacing: DesignSpacing.xSmall) {
                HStack {
                    Text(route.colourOrTag).font(.headline)
                    if route.lifecycle == .archived {
                        StatusChip(title: L10n.Route.archived, systemImage: "archivebox", colour: DesignColour.archived)
                    }
                }
                ViewThatFits(in: .horizontal) {
                    metadata
                    VStack(alignment: .leading, spacing: DesignSpacing.xSmall) { metadata }
                }
                if route.communityGradeSummary.displayGrade == nil, route.communityGradeSummary.voteCount > 0 {
                    Text(route.communityGradeSummary.voteCount, format: .number) + Text(L10n.Route.validVotesSuffix)
                        .font(.caption2)
                        .foregroundStyle(DesignColour.textTertiary)
                }
                if let reset = route.resetDate {
                    Label(reset.formatted(.relative(presentation: .named)), systemImage: "clock")
                        .font(.caption2)
                        .foregroundStyle(DesignColour.tertiaryText)
                }
                if let status {
                    StatusChip(title: L10n.logbookStatus(status), systemImage: statusIcon(status), colour: DesignColour.brandPrimary)
                }
            }
        }
        .padding(.vertical, DesignSpacing.small)
        .accessibilityElement(children: .combine)
    }

    private var metadata: some View {
        HStack(spacing: DesignSpacing.compact) {
            Label(route.officialGrade?.displayName ?? String(localized: L10n.Grade.unknown), systemImage: "number")
                    if let community = route.communityGradeSummary.displayGrade {
                Label {
                    Text(L10n.Route.communityShortLabel) + Text(verbatim: " \(community.displayName)")
                } icon: {
                    Image(systemName: "person.3")
                }
                    }
            Label("\(route.betaCount)", systemImage: "link")
        }
        .font(.caption)
        .foregroundStyle(DesignColour.textSecondary)
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

#Preview("Wall Zone Route List") {
    let environment = AppEnvironment.development(authenticationState: .signedIn(DevelopmentFixtures.mockProfile))
    let session = AppSession(environment: environment)
    NavigationStack {
        WallZoneRouteListView(
            wallZone: DevelopmentFixtures.wallZones[0],
            environment: environment,
            session: session
        )
    }
    .task { await session.load() }
}

#Preview("Wall Zone Route List — Offline") {
    let environment = AppEnvironment.development(scenario: .offlineWithoutCache)
    NavigationStack {
        WallZoneRouteListView(
            wallZone: DevelopmentFixtures.wallZones[0],
            environment: environment,
            session: AppSession(environment: environment)
        )
    }
}
