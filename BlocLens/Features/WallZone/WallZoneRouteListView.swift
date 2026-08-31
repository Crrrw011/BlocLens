import SwiftUI

struct WallZoneRouteListView: View {
    let wallZone: WallZone
    let environment: AppEnvironment
    @ObservedObject var session: AppSession

    @StateObject private var viewModel: WallZoneRouteListViewModel
    @State private var showsArchived = false
    @State private var isAddRoutePresented = false
    @State private var isEditZonePresented = false
    @State private var isReportPresented = false
    @Namespace private var heroNS
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

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

    private var isCreator: Bool {
        guard let current = environment.currentUserID() else { return false }
        return wallZone.createdBy == current
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSpacing.medium) {
                titleGroup
                filterBar
                routeContent
            }
            .padding(.horizontal, DesignSpacing.medium)
            .padding(.top, DesignSpacing.medium)
            .padding(.bottom, DesignSpacing.large)
        }
        .navigationTitle("Zone Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    if session.requireAuthentication(for: .addRouteInZone(wallZoneID: wallZone.id)) {
                        isAddRoutePresented = true
                    }
                } label: {
                    Label(L10n.Gym.addRouteInZone, systemImage: "plus")
                }
                .accessibilityIdentifier("add-route-in-zone-button")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if isCreator {
                        Button {
                            isEditZonePresented = true
                        } label: {
                            Label(L10n.WallZone.edit, systemImage: "pencil")
                        }
                    }
                    Button(role: .destructive) {
                        isReportPresented = true
                    } label: {
                        Label(L10n.WallZone.reportIssue, systemImage: "exclamationmark.bubble")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityIdentifier("wall-zone-more-button")
            }
        }
        .sheet(isPresented: $isAddRoutePresented, onDismiss: {
            Task { await viewModel.load() }
        }) {
            AddContributionView(action: .addNewRoute, environment: environment, preselectedWallZone: wallZone)
        }
        .sheet(isPresented: $isEditZonePresented) {
            AddWallZoneView(environment: environment, session: session, gym: nil, existingZone: wallZone)
        }
        .sheet(isPresented: $isReportPresented) {
            ReportWallZoneView(environment: environment, wallZone: wallZone)
        }
        .searchable(text: $viewModel.options.query, prompt: Text(L10n.Search.routePrompt))
        .onSubmit(of: .search) { Task { await viewModel.load() } }
        .onChange(of: viewModel.options.query) { _, _ in Task { await viewModel.load() } }
        .onChange(of: viewModel.options.gradeBand) { _, _ in Task { await viewModel.load() } }
        .onChange(of: viewModel.options.hasBeta) { _, _ in Task { await viewModel.load() } }
        .onChange(of: viewModel.options.sort) { _, _ in Task { await viewModel.load() } }
        .onChange(of: session.resumedIntent) { _, intent in
            let expected = ProtectedIntent.addRouteInZone(wallZoneID: wallZone.id)
            guard intent == expected else { return }
            isAddRoutePresented = true
            session.consumeResumedIntent(expected)
        }
        .task { await viewModel.load() }
    }

    // MARK: - Zone header: WallName + Active/Inactive + Reset (same area)

    private var titleGroup: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.small) {
            // Reading order must be WallName -> Active/Inactive -> Reset even when wrapping
            ViewThatFits(in: .horizontal) {
                HStack(spacing: DesignSpacing.small) {
                    Text(verbatim: wallZone.name)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(DesignColour.textPrimary)
                        .lineLimit(1)
                        .accessibilityIdentifier("zone-wall-name")
                    statusBadge
                    resetBadge
                }
                VStack(alignment: .leading, spacing: DesignSpacing.xSmall) {
                    HStack(spacing: DesignSpacing.small) {
                        Text(verbatim: wallZone.name)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(DesignColour.textPrimary)
                            .lineLimit(2)
                        statusBadge
                    }
                    resetBadge
                }
            }
            if !wallZone.locationDescription.isEmpty {
                Text(verbatim: wallZone.locationDescription)
                    .font(DesignTypography.supporting)
                    .foregroundStyle(DesignColour.textSecondary)
                    .lineLimit(2)
                    .accessibilityIdentifier("zone-location")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("zone-header")
    }

    private var statusBadge: some View {
        Label {
            Text(wallZone.availability == .active ? "Active" : "Inactive")
                .font(BlocTypography.status)
        } icon: {
            Image(systemName: wallZone.availability == .active ? "checkmark.circle.fill" : "xmark.circle.fill")
        }
        .font(BlocTypography.status)
        .foregroundStyle(wallZone.availability == .active ? DesignColour.success : DesignColour.error)
        .padding(.horizontal, 8)
        .frame(minHeight: 24)
        .background(
            (wallZone.availability == .active ? DesignColour.success : DesignColour.error).opacity(0.12),
            in: Capsule()
        )
        .overlay { Capsule().stroke(wallZone.availability == .active ? DesignColour.success : DesignColour.error, lineWidth: 1) }
        .accessibilityLabel(Text(wallZone.availability == .active ? "Active" : "Inactive"))
        .accessibilityIdentifier("zone-status")
    }

    private var resetBadge: some View {
        Label(resetText, systemImage: "arrow.clockwise")
            .font(BlocTypography.caption)
            .foregroundStyle(DesignColour.textSecondary)
            .lineLimit(1)
            .accessibilityLabel(Text(resetText))
            .accessibilityIdentifier("zone-reset")
    }

    private var resetText: String {
        if let reset = wallZone.latestResetDate {
            let days = Calendar.current.dateComponents([.day], from: reset, to: Date()).day ?? 0
            if days == 0 { return "Reset today" }
            if days == 1 { return "Reset 1d" }
            if days < 7 { return "Reset \(days)d" }
            return reset.formatted(date: .abbreviated, time: .omitted)
        }
        return "Reset —"
    }

    // MARK: - Filter bar: Has Beta -> All Grades -> Newest

    private var filterBar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: DesignSpacing.small) {
                hasBetaToggle
                gradeMenu
                sortMenu
            }
            VStack(alignment: .leading, spacing: DesignSpacing.small) {
                HStack(spacing: DesignSpacing.small) {
                    hasBetaToggle
                    gradeMenu
                }
                sortMenu
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("filter-bar")
    }

    private var hasBetaToggle: some View {
        Toggle(isOn: $viewModel.options.hasBeta) {
            Label {
                Text("Has Beta")
                    .font(DesignTypography.supporting.weight(.semibold))
            } icon: {
                Image(systemName: viewModel.options.hasBeta ? "checkmark.circle.fill" : "circle")
            }
        }
        .toggleStyle(.button)
        .buttonStyle(CompactActionButtonStyle())
        .accessibilityLabel(Text("Has Beta"))
        .accessibilityValue(Text(viewModel.options.hasBeta ? "On" : "Off"))
        .accessibilityAddTraits(viewModel.options.hasBeta ? .isSelected : [])
        .accessibilityIdentifier("filter-has-beta")
        .frame(minHeight: 44)
    }

    private var gradeMenu: some View {
        Menu {
            ForEach(GradeBand.allCases, id: \.self) { band in
                Button {
                    viewModel.options.gradeBand = band
                } label: {
                    HStack {
                        Text(L10n.gradeBand(band))
                        if viewModel.options.gradeBand == band { Image(systemName: "checkmark") }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(viewModel.options.gradeBand == .all ? "All Grades" : String(localized: L10n.gradeBand(viewModel.options.gradeBand)))
                    .font(DesignTypography.supporting.weight(.semibold))
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .foregroundStyle(DesignColour.brandPrimary)
            .padding(.horizontal, DesignSpacing.medium)
            .frame(minHeight: 44)
            .background(DesignColour.brandTint, in: Capsule())
        }
        .accessibilityLabel(Text("Grade filter"))
        .accessibilityValue(Text(viewModel.options.gradeBand == .all ? "All Grades" : String(localized: L10n.gradeBand(viewModel.options.gradeBand))))
        .accessibilityIdentifier("filter-grade")
    }

    private var sortMenu: some View {
        Menu {
            ForEach(RouteSort.allCases, id: \.self) { sort in
                Button {
                    viewModel.options.sort = sort
                } label: {
                    HStack {
                        Text(L10n.routeSort(sort))
                        if viewModel.options.sort == sort { Image(systemName: "checkmark") }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(viewModel.options.sort == .newest ? "Newest" : String(localized: L10n.routeSort(viewModel.options.sort)))
                    .font(DesignTypography.supporting.weight(.semibold))
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .foregroundStyle(DesignColour.brandPrimary)
            .padding(.horizontal, DesignSpacing.medium)
            .frame(minHeight: 44)
            .background(DesignColour.brandTint, in: Capsule())
        }
        .accessibilityLabel(Text("Sort"))
        .accessibilityValue(Text(String(localized: L10n.routeSort(viewModel.options.sort))))
        .accessibilityIdentifier("filter-sort")
    }

    // MARK: - Route content

    @ViewBuilder
    private var routeContent: some View {
        switch viewModel.state {
        case .initial, .loading:
            LoadingStateView().frame(maxWidth: .infinity)
        case .loaded(let routes), .offlineWithCache(let routes):
            VStack(alignment: .leading, spacing: DesignSpacing.medium) {
                sectionContainer(title: L10n.RouteList.currentRoutes, routes: routes)
                if !viewModel.archivedRoutes.isEmpty {
                    DisclosureGroup(isExpanded: $showsArchived) {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(viewModel.archivedRoutes) { route in
                                NavigationLink(value: route) {
                                    RouteRow(route: route, status: visibleStatus(for: route))
                                }
                                .accessibilityIdentifier("route-row-\(route.id.rawValue)")
                                if route.id != viewModel.archivedRoutes.last?.id {
                                    Divider().opacity(0.5)
                                }
                            }
                        }
                        .padding(.top, DesignSpacing.small)
                    } label: {
                        Text(L10n.RouteList.archivedRoutes)
                            .font(DesignTypography.supporting.weight(.semibold))
                            .foregroundStyle(DesignColour.textSecondary)
                    }
                    .padding(DesignSpacing.medium)
                    .background(DesignColour.surfacePrimary, in: RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous).stroke(DesignColour.separator.opacity(0.5), lineWidth: 0.5) }
                }
            }
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
            .frame(maxWidth: .infinity)
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

    private func sectionContainer(title: LocalizedStringResource, routes: [ClimbingRoute]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(DesignTypography.supporting.weight(.semibold))
                .foregroundStyle(DesignColour.textSecondary)
                .padding(.horizontal, DesignSpacing.medium)
                .padding(.top, DesignSpacing.medium)
                .padding(.bottom, DesignSpacing.small)
            VStack(spacing: 0) {
                ForEach(routes) { route in
                    NavigationLink(value: route) {
                        RouteRow(route: route, status: visibleStatus(for: route))
                    }
                    .accessibilityIdentifier("route-row-\(route.id.rawValue)")
                    if route.id != routes.last?.id {
                        Divider().opacity(0.5).padding(.leading, DesignSpacing.medium + 12)
                    }
                }
            }
            .padding(.horizontal, DesignSpacing.medium)
            .padding(.bottom, DesignSpacing.small)
        }
        .background(DesignColour.surfacePrimary, in: RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous).stroke(DesignColour.separator.opacity(0.5), lineWidth: 0.5) }
    }

    private func visibleStatus(for route: ClimbingRoute) -> LogbookStatus? {
        session.authenticationState.isSignedIn ? viewModel.statusByRouteID[route.id] : nil
    }
}

private struct RouteRow: View {
    let route: ClimbingRoute
    let status: LogbookStatus?

    var body: some View {
        HStack(spacing: DesignSpacing.small) {
            HoldDot(colour: route.colour)
            // HoldColour·V·Status·Beta·Reset — high-density one-line
            HStack(spacing: 4) {
                Text(verbatim: route.colour)
                    .foregroundStyle(DesignColour.textPrimary)
                Text(verbatim: "·").foregroundStyle(DesignColour.textTertiary)
                Text(route.displayGrade?.displayName ?? String(localized: L10n.Grade.unknown))
                    .foregroundStyle(BlocColor.opticBlue)
                    .fontWeight(.semibold)
                if let status {
                    Text(verbatim: "·").foregroundStyle(DesignColour.textTertiary)
                    Text(L10n.logbookStatus(status))
                        .foregroundStyle(DesignColour.textSecondary)
                } else if route.lifecycle == .archived {
                    Text(verbatim: "·").foregroundStyle(DesignColour.textTertiary)
                    Text(L10n.Route.archived)
                        .foregroundStyle(DesignColour.archived)
                }
                Text(verbatim: "·").foregroundStyle(DesignColour.textTertiary)
                Label("\(route.betaCount)", systemImage: "link")
                    .foregroundStyle(DesignColour.textSecondary)
                Text(verbatim: "·").foregroundStyle(DesignColour.textTertiary)
                if let reset = route.resetDate {
                    Text(reset.formatted(.relative(presentation: .named)))
                        .foregroundStyle(DesignColour.textTertiary)
                } else {
                    Text(verbatim: "—").foregroundStyle(DesignColour.textTertiary)
                }
            }
            .font(BlocTypography.caption)
            .lineLimit(1)
            .truncationMode(.tail)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(DesignColour.textTertiary)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: "\(RouteColourPresentation.gradeAndShapeLabel(grade: route.displayGrade?.displayName, colour: route.colour)) \(route.betaCount) beta"))
    }
}

private struct HoldDot: View {
    let colour: String
    var size: CGFloat = 8

    var body: some View {
        Group {
            switch token.shape {
            case .circle: Circle().fill(fillColor)
            case .square: RoundedRectangle(cornerRadius: 1.5, style: .continuous).fill(fillColor)
            case .diamond: DiamondShape().fill(fillColor)
            }
        }
        .overlay {
            Group {
                switch token.shape {
                case .circle: Circle().stroke(DesignColour.separator.opacity(0.35), lineWidth: 0.5)
                case .square: RoundedRectangle(cornerRadius: 1.5, style: .continuous).stroke(DesignColour.separator.opacity(0.35), lineWidth: 0.5)
                case .diamond: DiamondShape().stroke(DesignColour.separator.opacity(0.35), lineWidth: 0.5)
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var token: BlocColor.HoldColor {
        let n = colour.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let exact = BlocColor.routePalette.first(where: { $0.name.lowercased() == n }) { return exact }
        if let partial = BlocColor.routePalette.first(where: { n.contains($0.name.lowercased()) }) { return partial }
        return BlocColor.grey
    }

    private var fillColor: Color { token.color }
}

private struct DiamondShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        p.closeSubpath()
        return p
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
