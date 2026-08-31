import SwiftUI

struct HomeView: View {
    let environment: AppEnvironment
    @ObservedObject var session: AppSession
    @StateObject private var viewModel: HomeViewModel
    @State private var showsFavouritePicker = false
    @Namespace private var heroNS
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    init(environment: AppEnvironment, session: AppSession) {
        self.environment = environment
        self.session = session
        _viewModel = StateObject(wrappedValue: HomeViewModel(environment: environment))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationDestination(for: Gym.self) { GymDetailView(gym: $0, environment: environment, session: session) }
                .navigationDestination(for: WallZone.self) { WallZoneRouteListView(wallZone: $0, environment: environment, session: session) }
                .navigationDestination(for: ClimbingRoute.self) { RouteDetailView(route: $0, environment: environment, session: session) }
        }
        .onAppear { Task { await viewModel.load(favouriteGymID: session.authenticationState.profile?.favouriteGymID) } }
        .onChange(of: session.authenticationState.profile?.favouriteGymID) { _, newID in
            Task { await viewModel.load(favouriteGymID: newID) }
        }
        .sheet(isPresented: $showsFavouritePicker) {
            FavouriteGymPickerView(environment: environment, selectedGymID: Binding(
                get: { session.authenticationState.profile?.favouriteGymID },
                set: { _ in }
            )) { gym in
                Task { await session.updateFavouriteGym(gym.id) }
            }
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
            EmptyStateView(title: L10n.Home.emptyTitle, message: L10n.Home.emptyMessage, systemImage: "house")
        case .error:
            ErrorStateView(message: L10n.State.fixtureErrorMessage) { Task { await viewModel.load() } }
        case .offlineWithoutCache:
            OfflineStateView(hasCachedData: false)
        }
    }

    private func dashboard(data: HomeDashboardData, isOffline: Bool) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let gym = data.frequentGym {
                    currentGymHero(gym: gym)
                    VStack(alignment: .leading, spacing: DesignSpacing.large) {
                        if isOffline { OfflineBanner(message: L10n.State.offlineCachedMessage) }
                        currentGymTitle(gym: gym)
                        Button {
                            if session.authenticationState.isSignedIn {
                                showsFavouritePicker = true
                            } else {
                                _ = session.requireAuthentication(for: .account)
                            }
                        } label: {
                            Label("Change Favourite Gym", systemImage: "pencil.circle")
                                .font(DesignTypography.supporting.weight(.medium))
                                .foregroundStyle(BlocColor.opticBlue)
                        }
                        Divider().overlay(DesignColour.separator.opacity(0.35)).padding(.horizontal, DesignSpacing.medium)
                        currentGymMetadata(gym: gym, data: data)
                        activeProjectsSection(data: data)
                        freshSetsSection(data: data)
                        recentClimbsSection(data: data)
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
                    .padding(.top, DesignSpacing.medium)
                    .padding(.bottom, DesignSpacing.large)
                } else {
                    if !session.authenticationState.isSignedIn {
                        // Guest: only Welcome, visually centered between nav and tab bar
                        VStack {
                            Spacer()
                            VStack(alignment: .leading, spacing: DesignSpacing.medium) {
                                Label("Welcome to BlocLens", systemImage: "mountain.2.circle")
                                    .font(.headline)
                                    .foregroundStyle(DesignColour.textPrimary)
                                Text("Sign in to personalise your home, track projects and get wall updates for your favourite gym.")
                                    .font(DesignTypography.supporting)
                                    .foregroundStyle(DesignColour.textSecondary)
                                Button { _ = session.requireAuthentication(for: .account) } label: {
                                    Label("Sign In", systemImage: "person.crop.circle.badge.checkmark")
                                }
                                .buttonStyle(PrimaryButtonStyle())
                            }
                            .padding(DesignSpacing.medium)
                            .background(DesignColour.surfacePrimary, in: RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous))
                            .overlay { RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous).stroke(DesignColour.separator.opacity(0.5), lineWidth: 0.5) }
                            .padding(.horizontal, DesignSpacing.medium)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, minHeight: 500)
                        .padding(.vertical, DesignSpacing.large)
                    } else {
                        // Signed-in but no favourite: Choose card + other sections, with more top breathing room
                        VStack(alignment: .leading, spacing: DesignSpacing.large) {
                            Color.clear.frame(height: 32)
                            if isOffline { OfflineBanner(message: L10n.State.offlineCachedMessage) }
                            VStack(alignment: .leading, spacing: DesignSpacing.medium) {
                                Label("Choose your favourite gym", systemImage: "star.circle")
                                    .font(.headline)
                                    .foregroundStyle(DesignColour.textPrimary)
                                Text("Select a gym to see its wall and reset information on your home screen.")
                                    .font(DesignTypography.supporting)
                                    .foregroundStyle(DesignColour.textSecondary)
                                Button { showsFavouritePicker = true } label: {
                                    Label("Select Favourite Gym", systemImage: "mappin.and.ellipse")
                                }
                                .buttonStyle(PrimaryButtonStyle())
                            }
                            .padding(DesignSpacing.medium)
                            .background(DesignColour.surfacePrimary, in: RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous))
                            .overlay { RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous).stroke(DesignColour.separator.opacity(0.5), lineWidth: 0.5) }
                            activeProjectsSection(data: data)
                            freshSetsSection(data: data)
                            recentClimbsSection(data: data)
                        }
                        .padding(.horizontal, DesignSpacing.medium)
                        .padding(.top, DesignSpacing.small)
                        .padding(.vertical, DesignSpacing.small)
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .safeAreaPadding(.top, 8)
        .background(DesignColour.backgroundSecondary)
    }

    // MARK: - Current Gym hero wall as interface

    private func currentGymHero(gym: Gym) -> some View {
        ZStack(alignment: .bottomLeading) {
            GymPhotoView(
                placeID: gym.googlePlaceID,
                gymName: gym.name,
                photoService: environment.gymPhotoService,
                width: 800,
                aspectRatio: 4 / 3
            )
            LinearGradient(colors: [.clear, Color.black.opacity(0.30)], startPoint: .top, endPoint: .bottom)
            floatingCapsules(gym: gym)
                .padding(.horizontal, DesignSpacing.medium)
                .padding(.bottom, DesignSpacing.medium)
        }
        .frame(maxWidth: .infinity)
        .clipped()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: "\(gym.name) \(gym.suburb)"))
    }

    private func floatingCapsules(gym: Gym) -> some View {
        HStack(spacing: DesignSpacing.small) {
            suburbCapsule(gym: gym)
            verifiedCapsule(gym: gym)
            resetCapsule(gym: gym)
            Spacer(minLength: 0)
        }
    }

    private func suburbCapsule(gym: Gym) -> some View {
        Text(verbatim: gym.suburb)
            .font(BlocTypography.grade)
            .foregroundStyle(Color(uiColor: .label))
            .padding(.horizontal, 14)
            .frame(minHeight: 32)
            .background(Color(uiColor: .systemBackground), in: Capsule())
            .overlay { Capsule().stroke(Color.black.opacity(0.08), lineWidth: 0.5) }
            .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
            .matchedGeometryEffect(id: "hero-grade-\(gym.id.rawValue)", in: heroNS, isSource: !reduceMotion)
            .accessibilityIdentifier("hero-suburb")
    }

    private func verifiedCapsule(gym: Gym) -> some View {
        Label {
            Text(gym.isVerified ? L10n.Gym.verified : L10n.Gym.community)
        } icon: {
            Image(systemName: gym.isVerified ? "checkmark.seal.fill" : "person.2")
        }
        .font(BlocTypography.status)
        .foregroundStyle(.white)
        .padding(.horizontal, BlocSpacing.compact)
        .frame(minHeight: 28)
        .background(glassCapsuleBackground)
        .overlay { Capsule().stroke(.white.opacity(0.18), lineWidth: 0.5) }
        .shadow(color: .black.opacity(0.16), radius: 8, y: 4)
        .accessibilityIdentifier("hero-verified")
    }

    private func resetCapsule(gym: Gym) -> some View {
        Label(resetCapsuleText(gym: gym), systemImage: "arrow.clockwise")
            .font(BlocTypography.status)
            .foregroundStyle(.white)
            .padding(.horizontal, BlocSpacing.compact)
            .frame(minHeight: 28)
            .background(glassCapsuleBackground)
            .overlay { Capsule().stroke(.white.opacity(0.18), lineWidth: 0.5) }
            .shadow(color: .black.opacity(0.16), radius: 8, y: 4)
            .accessibilityIdentifier("hero-reset")
    }

    private func resetCapsuleText(gym: Gym) -> String {
        if let reset = gym.latestResetDate {
            let days = Calendar.current.dateComponents([.day], from: reset, to: Date()).day ?? 0
            if days == 0 { return String(localized: L10n.Gym.resetToday) }
            if days == 1 { return String(localized: L10n.Gym.resetOneDay) }
            if days < 7 { return L10n.Gym.resetDays(days) }
            return reset.formatted(date: .abbreviated, time: .omitted)
        }
        return String(localized: L10n.Gym.resetUnknown)
    }

    @ViewBuilder
    private var glassCapsuleBackground: some View {
        if reduceTransparency {
            Capsule().fill(Color(uiColor: .secondarySystemBackground))
        } else if #available(iOS 26.0, *) {
            Capsule().fill(.ultraThinMaterial).overlay { Capsule().fill(BlocColor.opticBlueTint.opacity(0.12)) }
                .glassEffect(.regular.tint(BlocColor.opticBlueTint).interactive(false), in: Capsule())
        } else {
            Capsule().fill(.ultraThinMaterial).overlay { Capsule().fill(Color.black.opacity(0.18)) }
        }
    }

    private func currentGymTitle(gym: Gym) -> some View {
        VStack(alignment: .leading, spacing: DesignSpacing.xSmall) {
            NavigationLink(value: gym) {
                HStack(alignment: .firstTextBaseline, spacing: DesignSpacing.small) {
                    Text(verbatim: gym.name)
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(DesignColour.textPrimary)
                        .minimumScaleFactor(0.85)
                        .lineLimit(2)
                    if gym.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(BlocColor.opticBlue)
                            .accessibilityLabel(L10n.Gym.verified)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DesignColour.textTertiary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("hero-location")
            HStack(spacing: DesignSpacing.small) {
                Label(gym.brandName, systemImage: "building.2")
                Text(verbatim: "·")
                Text(verbatim: "\(gym.suburb), \(gym.state)")
                    .foregroundStyle(DesignColour.textSecondary)
                if gym.betaCount > 0 {
                    Text(verbatim: "·")
                    Label("\(gym.betaCount)", systemImage: "link")
                        .foregroundStyle(DesignColour.textSecondary)
                }
            }
            .font(DesignTypography.supporting)
            .foregroundStyle(DesignColour.textSecondary)
            .lineLimit(1)
            if let reset = gym.latestResetDate {
                Text(verbatim: "\(String(localized: "Last reset")) · \(reset.formatted(date: .abbreviated, time: .omitted))")
                    .font(BlocTypography.caption)
                    .foregroundStyle(DesignColour.textTertiary)
            }
        }
    }

    private func currentGymMetadata(gym: Gym, data: HomeDashboardData) -> some View {
        let zones = data.freshZones.isEmpty ? gym.wallZoneIDs.count : data.freshZones.count
        let beta = gym.betaCount
        let hardSoft = String(localized: L10n.hardSoft(gym.overallHardSoftSummary))
        return Text(verbatim: "\(gym.brandName) · \(gym.suburb), \(gym.state) · \(zones) zones · \(beta) beta · \(hardSoft)")
            .font(BlocTypography.metadata)
            .foregroundStyle(DesignColour.textSecondary)
            .lineLimit(1)
            .truncationMode(.tail)
            .accessibilityIdentifier("hero-metadata")
    }

    // MARK: - Active Projects sorted by reset urgency

    private func activeProjectsSection(data: HomeDashboardData) -> some View {
        VStack(alignment: .leading, spacing: DesignSpacing.small) {
            HStack(alignment: .firstTextBaseline, spacing: DesignSpacing.small) {
                Text(L10n.Home.activeProjects)
                    .font(DesignTypography.supporting.weight(.semibold))
                    .foregroundStyle(DesignColour.textPrimary)
                if !data.projects.isEmpty && session.authenticationState.isSignedIn {
                    Text(verbatim: "· \(data.projects.count) · sorted by reset")
                        .font(BlocTypography.caption)
                        .foregroundStyle(DesignColour.textTertiary)
                }
                Spacer()
                if data.projects.count > 3 {
                    NavigationLink(value: data.frequentGym as Gym?) {
                        Text(verbatim: "See all")
                            .font(BlocTypography.caption.weight(.semibold))
                            .foregroundStyle(BlocColor.opticBlue)
                    }
                }
            }
            .accessibilityIdentifier("home-projects-section")
            if !session.authenticationState.isSignedIn {
                VStack(alignment: .leading, spacing: DesignSpacing.small) {
                    Label(L10n.Home.privateLogbookMessage, systemImage: "lock.fill")
                        .font(DesignTypography.supporting)
                        .foregroundStyle(DesignColour.textSecondary)
                    Button(L10n.Home.privateLogbookAction) { _ = session.requireAuthentication(for: .account) }
                        .buttonStyle(CompactActionButtonStyle())
                }
                .padding(DesignSpacing.medium)
                .background(DesignColour.surfacePrimary, in: RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous).stroke(DesignColour.separator.opacity(0.5), lineWidth: 0.5) }
            } else if data.projects.isEmpty {
                Label(L10n.Home.noProjects, systemImage: "hammer")
                    .font(DesignTypography.supporting)
                    .foregroundStyle(DesignColour.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DesignSpacing.medium)
                    .background(DesignColour.surfacePrimary, in: RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous).stroke(DesignColour.separator.opacity(0.5), lineWidth: 0.5) }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(data.projects.enumerated()), id: \.element.id) { index, item in
                        NavigationLink(value: item.route) { projectRow(item, rank: index) }
                            .buttonStyle(.plain)
                        if item.id != data.projects.last?.id {
                            Divider().opacity(0.45).padding(.leading, 52)
                        }
                    }
                }
                .padding(.horizontal, DesignSpacing.medium)
                .padding(.vertical, DesignSpacing.xSmall)
                .background(DesignColour.surfacePrimary, in: RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous).stroke(DesignColour.separator.opacity(0.5), lineWidth: 0.5) }
            }
        }
    }

    private func projectRow(_ item: HomeProjectItem, rank: Int) -> some View {
        HStack(spacing: DesignSpacing.small) {
            gradeBadge(for: item.route)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(verbatim: item.route.colour)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DesignColour.textPrimary)
                        .lineLimit(1)
                    urgencyPill(for: item.route)
                }
                HStack(spacing: 4) {
                    Text(verbatim: item.wallZone.name)
                    Text(verbatim: "·").foregroundStyle(DesignColour.textTertiary)
                    Text(item.route.terrain == .slab ? String(localized: L10n.terrain(.slab)) : String(localized: L10n.terrain(item.route.terrain)))
                    if let count = item.entry.attemptCount, count > 0 {
                        Text(verbatim: "·").foregroundStyle(DesignColour.textTertiary)
                        Text(verbatim: "\(count) tries")
                    }
                    Text(verbatim: "·").foregroundStyle(DesignColour.textTertiary)
                    Text(L10n.logbookStatus(item.entry.status))
                }
                .font(BlocTypography.caption)
                .foregroundStyle(DesignColour.textSecondary)
                .lineLimit(1)
            }
            Spacer(minLength: DesignSpacing.small)
            VStack(alignment: .trailing, spacing: 2) {
                Label("\(item.route.betaCount)", systemImage: "link")
                    .font(BlocTypography.caption.weight(.semibold))
                    .foregroundStyle(item.route.betaCount > 0 ? BlocColor.opticBlue : DesignColour.textTertiary)
                Text(item.route.displayGrade?.displayName ?? String(localized: L10n.Grade.unknown))
                    .font(BlocTypography.caption)
                    .foregroundStyle(DesignColour.textTertiary)
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: "\(RouteColourPresentation.gradeAndShapeLabel(grade: item.route.displayGrade?.displayName, colour: item.route.colour)) \(urgencyText(for: item.route))"))
    }

    private func gradeBadge(for route: ClimbingRoute) -> some View {
        let grade = route.displayGrade?.displayName ?? String(localized: L10n.Grade.unknown)
        let token = holdToken(for: route.colour)
        return Text(verbatim: grade)
            .font(.system(size: 13, weight: .bold).monospacedDigit())
            .foregroundStyle(token.textColor)
            .frame(width: 40, height: 40)
            .background(token.color, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.black.opacity(0.08), lineWidth: 0.5) }
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func urgencyPill(for route: ClimbingRoute) -> some View {
        let text = urgencyText(for: route)
        let style = urgencyStyle(for: route)
        Text(verbatim: text)
            .font(.system(size: 10, weight: .bold))
            .tracking(0.04)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .foregroundStyle(style.foreground)
            .background(style.background, in: Capsule())
            .overlay { Capsule().stroke(style.border, lineWidth: 0.5) }
    }

    private func urgencyText(for route: ClimbingRoute) -> String {
        if let archive = route.expectedArchiveDate {
            let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: archive)).day ?? 0
            if days <= 0 { return String(localized: "Reset today") }
            if days == 1 { return "Reset 1d" }
            return "Reset \(days)d"
        }
        if let entry = findEntry(for: route), entry.status == .projecting, urgencyDays(for: route) == Int.max - 1 {
            return String(localized: L10n.logbookStatus(.projecting))
        }
        return String(localized: L10n.logbookStatus(.projecting))
    }

    private func findEntry(for route: ClimbingRoute) -> LogbookEntry? { nil }

    private struct PillStyle { let foreground: Color; let background: Color; let border: Color }
    private func urgencyStyle(for route: ClimbingRoute) -> PillStyle {
        if let archive = route.expectedArchiveDate {
            let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: archive)).day ?? 99
            if days <= 2 { return PillStyle(foreground: .white, background: BlocColor.resetSoon, border: BlocColor.resetSoon.opacity(0.2)) }
            if days <= 7 { return PillStyle(foreground: .white, background: BlocColor.project, border: BlocColor.project.opacity(0.2)) }
            return PillStyle(foreground: DesignColour.textSecondary, background: DesignColour.surfaceElevated, border: DesignColour.separator.opacity(0.4))
        }
        return PillStyle(foreground: BlocColor.project, background: BlocColor.project.opacity(0.12), border: BlocColor.project.opacity(0.22))
    }

    private func urgencyDays(for route: ClimbingRoute) -> Int {
        if let archive = route.expectedArchiveDate {
            return Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: archive)).day ?? Int.max
        }
        return Int.max - 1
    }

    private func holdToken(for colour: String) -> BlocColor.HoldColor {
        let n = colour.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let exact = BlocColor.routePalette.first(where: { $0.name.lowercased() == n }) { return exact }
        if let partial = BlocColor.routePalette.first(where: { n.contains($0.name.lowercased()) }) { return partial }
        return BlocColor.grey
    }

    // MARK: - Fresh Sets horizontal capsules

    private func freshSetsSection(data: HomeDashboardData) -> some View {
        VStack(alignment: .leading, spacing: DesignSpacing.small) {
            Text(L10n.Gym.freshSets)
                .font(.system(size: 11, weight: .bold))
                .tracking(0.08)
                .textCase(.uppercase)
                .foregroundStyle(DesignColour.textTertiary)
            if data.freshZones.isEmpty {
                Text(L10n.Gym.noResetData)
                    .font(DesignTypography.supporting)
                    .foregroundStyle(DesignColour.textSecondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignSpacing.small) {
                        ForEach(data.freshZones) { zone in
                            NavigationLink(value: zone) { freshCapsule(zone: zone) }
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .accessibilityIdentifier("fresh-sets-section")
    }

    private func freshCapsule(zone: WallZone) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: zone.name)
                .font(BlocTypography.status)
                .foregroundStyle(DesignColour.textPrimary)
                .lineLimit(1)
            HStack(spacing: 4) {
                Text(L10n.wallKind(zone.wallKind))
                Text(verbatim: "·")
                if let reset = zone.latestResetDate {
                    Text(reset.formatted(.relative(presentation: .named)))
                } else {
                    Text(verbatim: "—")
                }
            }
            .font(BlocTypography.caption)
            .foregroundStyle(DesignColour.textSecondary)
            .lineLimit(1)
            Label("\(zone.routeCount)", systemImage: "circle.hexagongrid")
                .font(BlocTypography.caption)
                .foregroundStyle(DesignColour.textTertiary)
        }
        .padding(.horizontal, DesignSpacing.compact)
        .padding(.vertical, DesignSpacing.small)
        .background(DesignColour.surfacePrimary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(DesignColour.separator.opacity(0.65), lineWidth: 0.5) }
        .shadow(color: .black.opacity(0.04), radius: 4, y: 1)
        .accessibilityIdentifier("fresh-zone-\(zone.id.rawValue)")
    }

    // MARK: - Recent Climbs Flighty timeline

    private func recentClimbsSection(data: HomeDashboardData) -> some View {
        VStack(alignment: .leading, spacing: DesignSpacing.small) {
            Text(L10n.Home.recentRecords)
                .font(.system(size: 11, weight: .bold))
                .tracking(0.08)
                .textCase(.uppercase)
                .foregroundStyle(DesignColour.textTertiary)
            if !session.authenticationState.isSignedIn {
                // Guest already sees sign-in prompt in Active Projects — don't duplicate
                Label(L10n.Home.privateLogbookMessage, systemImage: "lock.fill")
                    .font(DesignTypography.supporting)
                    .foregroundStyle(DesignColour.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DesignSpacing.medium)
                    .background(DesignColour.surfacePrimary, in: RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous).stroke(DesignColour.separator.opacity(0.5), lineWidth: 0.5) }
            } else if data.recentRecords.isEmpty {
                Text(L10n.Home.noProjects)
                    .font(DesignTypography.supporting)
                    .foregroundStyle(DesignColour.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DesignSpacing.medium)
                    .background(DesignColour.surfacePrimary, in: RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous).stroke(DesignColour.separator.opacity(0.5), lineWidth: 0.5) }
            } else {
                timelineList(records: data.recentRecords)
            }
        }
    }

    private func timelineList(records: [HomeRecordItem]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(records.enumerated()), id: \.element.id) { index, item in
                NavigationLink(value: item.route) {
                    HStack(alignment: .top, spacing: DesignSpacing.small) {
                        timelineDot(isFirst: index == 0)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Text(item.entry.date.formatted(date: .omitted, time: .shortened))
                                    .font(BlocTypography.caption.weight(.semibold))
                                    .foregroundStyle(DesignColour.textPrimary)
                                Text(verbatim: "·").foregroundStyle(DesignColour.textTertiary).font(BlocTypography.caption)
                                Text(item.gym.name)
                                    .font(BlocTypography.caption)
                                    .foregroundStyle(DesignColour.textSecondary)
                                    .lineLimit(1)
                            }
                            HStack(spacing: 4) {
                                HoldDot(colour: item.route.colour, size: 8)
                                Text(verbatim: item.route.colour)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(DesignColour.textPrimary)
                                Text(verbatim: "·").foregroundStyle(DesignColour.textTertiary).font(BlocTypography.caption)
                                Text(item.route.displayGrade?.displayName ?? String(localized: L10n.Grade.unknown))
                                    .font(BlocTypography.caption.weight(.semibold))
                                    .foregroundStyle(BlocColor.opticBlue)
                                Text(verbatim: "·").foregroundStyle(DesignColour.textTertiary).font(BlocTypography.caption)
                                Text(L10n.logbookStatus(item.entry.status))
                                    .font(BlocTypography.caption.weight(.semibold))
                                    .foregroundStyle(timelineStatusColor(item.entry.status))
                                if let count = item.entry.attemptCount, item.entry.status == .sent || item.entry.status == .flash {
                                    Text(verbatim: "· \(count) try\(count == 1 ? "" : "s")")
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
                }
                .buttonStyle(.plain)
                if item.id != records.last?.id {
                    Divider().opacity(0.4).padding(.leading, DesignSpacing.medium + 12)
                }
            }
        }
        .background(DesignColour.surfacePrimary, in: RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous).stroke(DesignColour.separator.opacity(0.5), lineWidth: 0.5) }
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(DesignColour.separator.opacity(0.5))
                .frame(width: 1)
                .padding(.leading, DesignSpacing.medium + 5)
                .padding(.vertical, DesignSpacing.medium)
                .allowsHitTesting(false)
        }
    }

    private func timelineDot(isFirst: Bool) -> some View {
        Circle()
            .fill(isFirst ? BlocColor.opticBlue : Color(uiColor: .systemBackground))
            .frame(width: 10, height: 10)
            .overlay { Circle().stroke(isFirst ? BlocColor.opticBlue : DesignColour.separator, lineWidth: isFirst ? 0 : 1.5) }
            .overlay { if isFirst { Circle().stroke(Color.white.opacity(0.9), lineWidth: 2) } }
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

    private func compactEmpty(message: LocalizedStringResource, systemImage: String) -> some View {
        Label(message, systemImage: systemImage)
            .font(DesignTypography.supporting)
            .foregroundStyle(DesignColour.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignSpacing.medium)
            .background(DesignColour.surfacePrimary, in: RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous).stroke(DesignColour.separator.opacity(0.5), lineWidth: 0.5) }
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
