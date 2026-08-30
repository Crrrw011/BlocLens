import SwiftUI

struct LogbookView: View {
    let environment: AppEnvironment
    @ObservedObject var session: AppSession

    @StateObject private var viewModel: LogbookViewModel
    @Namespace private var filterNS
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
            Spacer()
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
            Spacer()
            Spacer()
        }
        .padding(.vertical, DesignSpacing.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignColour.backgroundSecondary)
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
            VStack(spacing: DesignSpacing.medium) {
                EmptyStateView(title: L10n.Logbook.emptyTitle, message: L10n.Logbook.emptyMessage, systemImage: "book.closed")
                Button(L10n.Logbook.findRoute) { session.selectedTab = .map }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, DesignSpacing.large)
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

    // MARK: - Flighty timeline dashboard

    private func dashboard(data: LogbookDashboardData, isOffline: Bool) -> some View {
        let filtered = viewModel.filteredRecords(from: data)
        let groups = timelineGroups(from: filtered)
        return ScrollView {
            VStack(alignment: .leading, spacing: BlocSpacing.sectionGap) {
                if isOffline {
                    OfflineBanner(message: L10n.State.offlineCachedMessage)
                }
                // Compact stats — Flighty secondary, not hero
                statsStrip(data: data)
                filterBar
                if !data.projects.isEmpty {
                    projectsSection(items: data.projects)
                }
                timelineSection(groups: groups, isFiltered: filtered.count != data.recentRecords.count)
            }
            .padding(.horizontal, DesignSpacing.medium)
            .padding(.top, DesignSpacing.small)
            .padding(.bottom, DesignSpacing.large)
        }
        .background(DesignColour.backgroundSecondary)
        .accessibilityIdentifier("logbook-dashboard")
    }

    // MARK: - Stats strip

    private func statsStrip(data: LogbookDashboardData) -> some View {
        VStack(alignment: .leading, spacing: DesignSpacing.small) {
            HStack(spacing: DesignSpacing.medium) {
                statCell(value: "\(data.statistics.climbingCount)", label: L10n.Logbook.climbingCount)
                Divider().frame(height: 28).opacity(0.3)
                statCell(value: "\(data.statistics.sentCount)", label: L10n.Logbook.sentCount)
                Divider().frame(height: 28).opacity(0.3)
                statCell(value: "\(data.statistics.flashCount)", label: L10n.Logbook.flashCount)
                Divider().frame(height: 28).opacity(0.3)
                statCell(value: data.statistics.highestGrade?.displayName ?? String(localized: L10n.Grade.unknown), label: L10n.Logbook.highestGrade, isGrade: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if !data.statistics.gradeDistribution.isEmpty {
                gradeDistributionCompact(data: data.statistics)
            }
            Label(L10n.Logbook.privateByDefaultMessage, systemImage: "lock.fill")
                .font(BlocTypography.caption)
                .foregroundStyle(DesignColour.textTertiary)
        }
        .padding(DesignSpacing.medium)
        .background(DesignColour.surfacePrimary, in: RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous).stroke(DesignColour.separator.opacity(0.5), lineWidth: 0.5) }
        .accessibilityElement(children: .combine)
    }

    private func statCell(value: String, label: LocalizedStringResource, isGrade: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: value)
                .font(isGrade ? BlocTypography.grade : .system(size: 20, weight: .bold).monospacedDigit())
                .foregroundStyle(isGrade ? BlocColor.opticBlue : DesignColour.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.06)
                .textCase(.uppercase)
                .foregroundStyle(DesignColour.textTertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func gradeDistributionCompact(data: LogbookStatistics) -> some View {
        let maxCount = data.gradeDistribution.values.max() ?? 1
        let sorted = data.gradeDistribution.keys.sorted()
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(sorted, id: \.self) { grade in
                let count = data.gradeDistribution[grade, default: 0]
                HStack(spacing: DesignSpacing.small) {
                    Text(verbatim: grade.displayName)
                        .font(BlocTypography.caption.weight(.semibold))
                        .foregroundStyle(DesignColour.textSecondary)
                        .frame(width: 28, alignment: .leading)
                    GeometryReader { proxy in
                        Capsule()
                            .fill(DesignColour.surfaceElevated)
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(BlocColor.opticBlue)
                                    .frame(width: proxy.size.width * CGFloat(count) / CGFloat(max(maxCount, 1)))
                            }
                    }
                    .frame(height: 6)
                    Text(verbatim: "\(count)")
                        .font(BlocTypography.caption)
                        .foregroundStyle(DesignColour.textTertiary)
                        .frame(width: 18, alignment: .trailing)
                }
            }
        }
    }

    // MARK: - Filter bar (Flighty pills, not List picker)

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.small) {
            Text(L10n.Logbook.filters)
                .font(.system(size: 11, weight: .bold))
                .tracking(0.08)
                .textCase(.uppercase)
                .foregroundStyle(DesignColour.textTertiary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSpacing.small) {
                    filterPill(title: String(localized: L10n.Common.all), isSelected: viewModel.statusFilter == nil) {
                        viewModel.statusFilter = nil
                    }
                    ForEach(LogbookStatus.allCases, id: \.self) { status in
                        filterPill(
                            title: String(localized: L10n.logbookStatus(status)).uppercased(),
                            isSelected: viewModel.statusFilter == status
                        ) {
                            viewModel.statusFilter = status
                        }
                    }
                }
            }
            Toggle(L10n.Logbook.lastThirtyDays, isOn: $viewModel.recentOnly)
                .font(DesignTypography.supporting)
                .tint(BlocColor.opticBlue)
        }
        .accessibilityIdentifier("logbook-filters")
    }

    private func filterPill(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            if !reduceMotion { BlocHaptics.selectionChanged() }
            action()
        } label: {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(BlocColor.opticBlue)
                        .matchedGeometryEffect(id: "logbook-filter-selection", in: filterNS, isSource: !reduceMotion)
                }
                Text(verbatim: title)
                    .font(BlocTypography.status)
                    .lineLimit(1)
                    .foregroundStyle(isSelected ? .white : DesignColour.textPrimary)
                    .contentTransition(.opacity)
            }
            .padding(.horizontal, DesignSpacing.medium)
            .frame(minWidth: 48, minHeight: 44)
            .background(isSelected ? Color.clear : DesignColour.surfacePrimary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(isSelected ? Color.clear : DesignColour.separator.opacity(0.65), lineWidth: 0.5) }
            .shadow(color: isSelected ? .clear : .black.opacity(0.04), radius: 4, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .animation(BlocMotion.animation(BlocMotion.quick, reduceMotion: reduceMotion), value: isSelected)
    }

    // MARK: - Projects compact (if any)

    private func projectsSection(items: [LogbookRecordItem]) -> some View {
        VStack(alignment: .leading, spacing: DesignSpacing.small) {
            Text(L10n.Logbook.projects)
                .font(.system(size: 11, weight: .bold))
                .tracking(0.08)
                .textCase(.uppercase)
                .foregroundStyle(DesignColour.textTertiary)
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    NavigationLink(value: item.route) { projectRow(item) }
                        .buttonStyle(.plain)
                    if item.id != items.last?.id {
                        Divider().opacity(0.4).padding(.leading, DesignSpacing.medium + 12)
                    }
                }
            }
            .background(DesignColour.surfacePrimary, in: RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous).stroke(DesignColour.separator.opacity(0.5), lineWidth: 0.5) }
        }
    }

    private func projectRow(_ item: LogbookRecordItem) -> some View {
        HStack(spacing: DesignSpacing.small) {
            HoldDot(colour: item.route.colour, size: 10)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(verbatim: item.route.colour)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DesignColour.textPrimary)
                    Text(verbatim: "·").foregroundStyle(DesignColour.textTertiary)
                    Text(verbatim: item.route.displayGrade?.displayName ?? String(localized: L10n.Grade.unknown))
                        .font(BlocTypography.caption.weight(.semibold))
                        .foregroundStyle(BlocColor.opticBlue)
                }
                .lineLimit(1)
                Text(L10n.logbookStatus(item.entry.status))
                    .font(BlocTypography.caption)
                    .foregroundStyle(DesignColour.textSecondary)
            }
            Spacer(minLength: DesignSpacing.small)
            if let count = item.entry.attemptCount, count > 0 {
                Text(verbatim: "\(count) tries")
                    .font(BlocTypography.caption)
                    .foregroundStyle(DesignColour.textTertiary)
            }
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(DesignColour.textTertiary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, DesignSpacing.medium)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    // MARK: - Timeline TODAY → Time+State+Object

    private func timelineSection(groups: [(date: Date, title: String, items: [LogbookRecordItem])], isFiltered: Bool) -> some View {
        VStack(alignment: .leading, spacing: DesignSpacing.small) {
            HStack(alignment: .firstTextBaseline, spacing: DesignSpacing.small) {
                Text(L10n.Logbook.recentRecords)
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.08)
                    .textCase(.uppercase)
                    .foregroundStyle(DesignColour.textTertiary)
                if !groups.isEmpty {
                    Text(verbatim: "· \(groups.flatMap(\.items).count)")
                        .font(BlocTypography.caption)
                        .foregroundStyle(DesignColour.textTertiary)
                }
                Spacer()
                if isFiltered {
                    Button {
                        viewModel.statusFilter = nil
                        viewModel.recentOnly = false
                    } label: {
                        Text(verbatim: "Clear")
                            .font(BlocTypography.caption.weight(.semibold))
                            .foregroundStyle(BlocColor.opticBlue)
                    }
                }
            }

            if groups.isEmpty {
                Text(L10n.Logbook.noMatchingRecords)
                    .font(DesignTypography.supporting)
                    .foregroundStyle(DesignColour.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DesignSpacing.medium)
                    .background(DesignColour.surfacePrimary, in: RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous).stroke(DesignColour.separator.opacity(0.5), lineWidth: 0.5) }
            } else {
                ForEach(groups, id: \.date) { group in
                    VStack(alignment: .leading, spacing: DesignSpacing.xSmall) {
                        Text(verbatim: group.title)
                            .font(.system(size: 11, weight: .bold))
                            .tracking(0.06)
                            .textCase(.uppercase)
                            .foregroundStyle(DesignColour.textSecondary)
                            .padding(.leading, DesignSpacing.xSmall)
                        VStack(spacing: 0) {
                            ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                                NavigationLink(value: item.route) { timelineRow(item, isFirst: index == 0) }
                                    .buttonStyle(.plain)
                                if item.id != group.items.last?.id {
                                    Divider().opacity(0.4).padding(.leading, DesignSpacing.medium + 12)
                                }
                            }
                        }
                        .background(DesignColour.surfacePrimary, in: RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous))
                        .overlay { RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous).stroke(DesignColour.separator.opacity(0.5), lineWidth: 0.5) }
                        .overlay(alignment: .leading) {
                            Rectangle()
                                .fill(DesignColour.separator.opacity(0.35))
                                .frame(width: 1)
                                .padding(.leading, DesignSpacing.medium + 5)
                                .padding(.vertical, DesignSpacing.medium)
                                .allowsHitTesting(false)
                        }
                    }
                }
            }
        }
    }

    private func timelineRow(_ item: LogbookRecordItem, isFirst: Bool) -> some View {
        HStack(alignment: .top, spacing: DesignSpacing.small) {
            timelineDot(isFirst: isFirst, status: item.entry.status)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(verbatim: timeString(for: item.entry.date))
                        .font(BlocTypography.caption.weight(.semibold))
                        .foregroundStyle(DesignColour.textPrimary)
                    Text(verbatim: "·").foregroundStyle(DesignColour.textTertiary).font(BlocTypography.caption)
                    Text(verbatim: String(localized: L10n.logbookStatus(item.entry.status)).uppercased())
                        .font(BlocTypography.caption.weight(.bold))
                        .foregroundStyle(timelineStatusColor(item.entry.status))
                    if item.entry.syncState == .queued {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(DesignColour.warning)
                            .accessibilityLabel(L10n.Logbook.queued)
                    }
                }
                HStack(spacing: 4) {
                    HoldDot(colour: item.route.colour, size: 8)
                    Text(verbatim: item.route.colour)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DesignColour.textPrimary)
                    Text(verbatim: "·").foregroundStyle(DesignColour.textTertiary).font(BlocTypography.caption)
                    Text(verbatim: item.route.displayGrade?.displayName ?? String(localized: L10n.Grade.unknown))
                        .font(BlocTypography.caption.weight(.semibold))
                        .foregroundStyle(BlocColor.opticBlue)
                    if let count = item.entry.attemptCount, count > 0 {
                        Text(verbatim: "· \(count) \(count == 1 ? "try" : "tries")")
                            .font(BlocTypography.caption)
                            .foregroundStyle(DesignColour.textTertiary)
                    }
                }
                .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(DesignColour.textTertiary)
                .padding(.top, 2)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, DesignSpacing.medium)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: "\(timeString(for: item.entry.date)) \(RouteColourPresentation.gradeAndShapeLabel(grade: item.route.displayGrade?.displayName, colour: item.route.colour)) \(String(localized: L10n.logbookStatus(item.entry.status)))"))
    }

    private func timelineDot(isFirst: Bool, status: LogbookStatus) -> some View {
        Circle()
            .fill(isFirst ? timelineStatusColor(status) : Color(uiColor: .systemBackground))
            .frame(width: 10, height: 10)
            .overlay { Circle().stroke(isFirst ? timelineStatusColor(status) : DesignColour.separator, lineWidth: isFirst ? 0 : 1.5) }
            .overlay { if isFirst { Circle().stroke(Color.white.opacity(0.9), lineWidth: 1.5) } }
            .padding(.top, 2)
            .accessibilityHidden(true)
    }

    private func timelineStatusColor(_ status: LogbookStatus) -> Color {
        switch status {
        case .flash: DesignColour.success
        case .sent: BlocColor.opticBlue
        case .projecting: BlocColor.project
        case .wantToTry: DesignColour.textSecondary
        }
    }

    // MARK: - Grouping

    private func timelineGroups(from items: [LogbookRecordItem]) -> [(date: Date, title: String, items: [LogbookRecordItem])] {
        let sorted = items.sorted { $0.entry.date > $1.entry.date }
        let cal = Calendar.current
        let grouped = Dictionary(grouping: sorted) { cal.startOfDay(for: $0.entry.date) }
        let days = grouped.keys.sorted(by: >)
        return days.map { day in
            let title: String
            if cal.isDateInToday(day) { title = "TODAY" }
            else if cal.isDateInYesterday(day) { title = "YESTERDAY" }
            else { title = day.formatted(date: .abbreviated, time: .omitted).uppercased() }
            return (date: day, title: title, items: (grouped[day] ?? []).sorted { $0.entry.date > $1.entry.date })
        }
    }

    private func timeString(for date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
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
