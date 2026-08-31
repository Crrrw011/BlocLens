import SwiftUI

struct GymDetailView: View {
    let gym: Gym
    let environment: AppEnvironment
    @ObservedObject var session: AppSession

    @StateObject private var viewModel: GymDetailViewModel
    @State private var isFavourite = false
    @State private var isAddWallZonePresented = false
    @Namespace private var heroNS
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    init(gym: Gym, environment: AppEnvironment, session: AppSession) {
        self.gym = gym
        self.environment = environment
        self.session = session
        _viewModel = StateObject(
            wrappedValue: GymDetailViewModel(
                gym: gym,
                gymRepository: environment.gymRepository,
                routeRepository: environment.routeRepository
            )
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                heroPhotoSection
                VStack(alignment: .leading, spacing: BlocSpacing.sectionGap) {
                    titleGroup
                    Divider().overlay(DesignColour.separator.opacity(0.6))
                    compactMetadataRow
                    stateSection
                    freshSetsSection
                    wallZonesAndRoutesSection
                    facilitiesSection
                    contactSection
                    if session.isContributionPromptVisible("gym-\(gym.id.rawValue)") {
                        ContributionPromptView(
                            title: L10n.Gym.contributionTitle,
                            message: L10n.Gym.contributionMessage,
                            primaryActionTitle: L10n.Home.contributionAction,
                            primaryAction: {
                                _ = session.requireAuthentication(for: .account)
                            },
                            dismissAction: {
                                session.dismissContributionPrompt("gym-\(gym.id.rawValue)")
                            }
                        )
                    }
                }
                .padding(.horizontal, DesignSpacing.medium)
                .padding(.top, DesignSpacing.medium)
                .padding(.bottom, DesignSpacing.large)
            }
        }
        .ignoresSafeArea(edges: .top)
        .navigationTitle(L10n.Gym.detailTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    if session.requireAuthentication(for: .account) {
                        isAddWallZonePresented = true
                    }
                } label: {
                    Label(L10n.Gym.addWallZone, systemImage: "plus")
                }
                .accessibilityIdentifier("add-wall-zone-button")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { isFavourite.toggle() } label: {
                    Image(systemName: isFavourite ? "star.fill" : "star")
                }
                .buttonStyle(IconButtonStyle())
                .accessibilityLabel(L10n.Profile.favouriteGym)
                .accessibilityValue(isFavourite ? L10n.Common.selected : L10n.Common.notSelected)
                .accessibilityIdentifier("favourite-gym-button")
            }
        }
        .sheet(isPresented: $isAddWallZonePresented, onDismiss: {
            Task { await viewModel.load() }
        }) {
            AddWallZoneView(environment: environment, session: session, gym: gym)
        }
        .task { await viewModel.load() }
        .onAppear {
            isFavourite = session.authenticationState.profile?.favouriteGymID == gym.id
        }
    }

    // MARK: - Hero L0 wall as interface

    private var heroPhotoSection: some View {
        ZStack(alignment: .bottomTrailing) {
            GymPhotoView(
                placeID: gym.googlePlaceID,
                gymName: gym.name,
                photoService: environment.gymPhotoService,
                width: 1200,
                aspectRatio: 4 / 3,
                cornerRadius: 0
            )
            LinearGradient(colors: [.clear, Color.black.opacity(0.30)], startPoint: .top, endPoint: .bottom)
            floatingCapsules
                .padding(.horizontal, DesignSpacing.medium)
                .padding(.bottom, DesignSpacing.medium)
        }
        .frame(maxWidth: .infinity)
        .clipped()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: "\(gym.name) \(gym.suburb)"))
    }

    private var floatingCapsules: some View {
        HStack(spacing: DesignSpacing.small) {
            Spacer(minLength: 0)
            verifiedCapsuleGlass
            resetCapsuleGlass
        }
    }

    private var suburbCapsuleSolid: some View {
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

    private var verifiedCapsuleGlass: some View {
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

    private var resetCapsuleGlass: some View {
        Label(resetCapsuleText, systemImage: "arrow.clockwise")
            .font(BlocTypography.status)
            .foregroundStyle(.white)
            .padding(.horizontal, BlocSpacing.compact)
            .frame(minHeight: 28)
            .background(glassCapsuleBackground)
            .overlay { Capsule().stroke(.white.opacity(0.18), lineWidth: 0.5) }
            .shadow(color: .black.opacity(0.16), radius: 8, y: 4)
            .accessibilityIdentifier("hero-reset")
    }

    private var resetCapsuleText: String {
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

    // MARK: - Title group no card

    private var titleGroup: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.xSmall) {
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
            }
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
                Text(reset.formatted(date: .abbreviated, time: .omitted))
                    .font(BlocTypography.caption)
                    .foregroundStyle(DesignColour.textTertiary)
            }
            Label(L10n.Gym.developmentFixture, systemImage: "hammer")
                .font(BlocTypography.caption)
                .foregroundStyle(DesignColour.warning)
        }
    }

    // MARK: - Compact metadata row

    private var compactMetadataRow: some View {
        let brand = gym.brandName
        let location = "\(gym.suburb), \(gym.state)"
        let zones = viewModel.freshZones.isEmpty ? gym.wallZoneIDs.count : viewModel.freshZones.count
        let beta = gym.betaCount
        let hardSoft = String(localized: L10n.hardSoft(gym.overallHardSoftSummary))
        return Text(verbatim: "\(brand) · \(location) · \(zones) zones · \(beta) beta · \(hardSoft)")
            .font(BlocTypography.metadata)
            .foregroundStyle(DesignColour.textSecondary)
            .lineLimit(1)
            .truncationMode(.tail)
            .accessibilityIdentifier("hero-metadata")
    }

    // MARK: - State (Hard/Soft + Operating)

    private var stateSection: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.small) {
            Text(L10n.Gym.hardSoftIndex)
                .font(DesignTypography.supporting.weight(.semibold))
                .foregroundStyle(DesignColour.textSecondary)
            VStack(spacing: 0) {
                hardSoftRow(label: L10n.Gym.overall, value: L10n.hardSoft(gym.overallHardSoftSummary), emphasized: true)
                Divider().opacity(0.5)
                ForEach([GradeBand.v0ToV2, .v3ToV5, .v6Plus], id: \.self) { band in
                    hardSoftRow(label: L10n.gradeBand(band), value: L10n.Gym.fixtureBandSummary)
                    if band != .v6Plus { Divider().opacity(0.35) }
                }
            }
            .padding(.horizontal, DesignSpacing.medium)
            .padding(.vertical, DesignSpacing.small)
            .background(DesignColour.surfacePrimary, in: RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous).stroke(DesignColour.separator.opacity(0.5), lineWidth: 0.5) }
            Text(L10n.Gym.communityEstimateNotice)
                .font(BlocTypography.caption)
                .foregroundStyle(DesignColour.textTertiary)
            HStack(spacing: DesignSpacing.small) {
                Label {
                    Text(gym.isVerified ? L10n.Gym.verified : L10n.Gym.community)
                } icon: {
                    Image(systemName: gym.isVerified ? "checkmark.seal.fill" : "person.2")
                }
                Text(verbatim: "·")
                Text(L10n.Gym.operatingFixtureMessage)
            }
            .font(BlocTypography.caption)
            .foregroundStyle(DesignColour.textSecondary)
        }
    }

    private func hardSoftRow(
        label: LocalizedStringResource,
        value: LocalizedStringResource,
        emphasized: Bool = false
    ) -> some View {
        HStack(spacing: DesignSpacing.compact) {
            Text(label).font(emphasized ? .headline : .subheadline.weight(.semibold))
            Spacer()
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(emphasized ? BlocColor.opticBlue : DesignColour.textSecondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, DesignSpacing.xSmall)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Fresh Sets

    private var freshSetsSection: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.small) {
            HStack {
                Label { Text(L10n.Gym.freshSets) } icon: { Image(systemName: "arrow.clockwise.circle.fill") }
                    .font(DesignTypography.supporting.weight(.semibold))
                    .foregroundStyle(DesignColour.textSecondary)
                Spacer()
                if let latest = gym.latestResetDate {
                    Text(latest.formatted(.relative(presentation: .named)))
                        .font(BlocTypography.caption)
                        .foregroundStyle(DesignColour.textTertiary)
                }
            }
            if viewModel.freshZones.isEmpty {
                if case .empty = viewModel.state {
                    Text(L10n.WallZone.emptyMessage)
                        .font(DesignTypography.supporting)
                        .foregroundStyle(DesignColour.textSecondary)
                } else {
                    Text(L10n.Gym.noResetData)
                        .font(DesignTypography.supporting)
                        .foregroundStyle(DesignColour.textSecondary)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignSpacing.small) {
                        ForEach(viewModel.freshZones.prefix(6)) { zone in
                            freshSetChip(zone: zone)
                        }
                    }
                }
            }
            if let latest = gym.latestResetDate {
                Label {
                    Text(latest.formatted(date: .long, time: .omitted))
                } icon: { Image(systemName: "calendar") }
                .font(BlocTypography.caption)
                .foregroundStyle(DesignColour.textTertiary)
            }
        }
        .padding(DesignSpacing.medium)
        .background(DesignColour.surfacePrimary, in: RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous).stroke(DesignColour.separator.opacity(0.5), lineWidth: 0.5) }
        .accessibilityIdentifier("fresh-sets-section")
    }

    private func freshSetChip(zone: WallZone) -> some View {
        NavigationLink(value: zone) {
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
            .background(DesignColour.surfaceElevated, in: Capsule())
            .overlay { Capsule().stroke(DesignColour.separator.opacity(0.45), lineWidth: 0.5) }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("fresh-zone-\(zone.id.rawValue)")
    }

    // MARK: - Wall Zones → Routes

    @ViewBuilder
    private var wallZonesAndRoutesSection: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.small) {
            HStack {
                Text(L10n.Gym.currentRoutesAndZones)
                    .font(DesignTypography.supporting.weight(.semibold))
                    .foregroundStyle(DesignColour.textSecondary)
                Spacer()
                if case .loaded = viewModel.state {
                    Text(verbatim: "\(viewModel.freshZones.count) zones")
                        .font(BlocTypography.caption)
                        .foregroundStyle(DesignColour.textTertiary)
                }
            }
            zonesContent
        }
    }

    @ViewBuilder
    private var zonesContent: some View {
        switch viewModel.state {
        case .initial, .loading:
            LoadingStateView().frame(maxWidth: .infinity)
        case .loaded(let zones), .offlineWithCache(let zones):
            VStack(alignment: .leading, spacing: DesignSpacing.medium) {
                ForEach(zones) { zone in
                    zoneCard(zone: zone)
                }
            }
        case .empty:
            EmptyStateView(
                title: L10n.WallZone.emptyTitle,
                message: L10n.WallZone.emptyMessage,
                systemImage: "square.stack.3d.up.slash"
            )
            .padding(DesignSpacing.medium)
            .background(DesignColour.surfacePrimary, in: RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous).stroke(DesignColour.separator.opacity(0.5), lineWidth: 0.5) }
        case .error:
            ErrorStateView(message: L10n.State.fixtureErrorMessage) {
                Task { await viewModel.load() }
            }
        case .offlineWithoutCache:
            Text(L10n.State.offlineNoCacheMessage)
                .foregroundStyle(DesignColour.secondaryText)
                .padding(DesignSpacing.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DesignColour.surfacePrimary, in: RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous).stroke(DesignColour.separator.opacity(0.5), lineWidth: 0.5) }
        }
    }

    private func zoneCard(zone: WallZone) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            NavigationLink(value: zone) {
                HStack(alignment: .center, spacing: DesignSpacing.small) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: zone.name)
                            .font(DesignTypography.cardTitle)
                            .foregroundStyle(DesignColour.textPrimary)
                        if !zone.locationDescription.isEmpty {
                            Text(verbatim: zone.locationDescription)
                                .font(BlocTypography.caption)
                                .foregroundStyle(DesignColour.textSecondary)
                                .lineLimit(1)
                        }
                        HStack(spacing: 4) {
                            Text(L10n.wallKind(zone.wallKind))
                                .font(BlocTypography.caption)
                                .foregroundStyle(BlocColor.opticBlue)
                            Text(verbatim: "·").foregroundStyle(DesignColour.textTertiary).font(BlocTypography.caption)
                            Label("\(zone.routeCount)", systemImage: "circle.hexagongrid")
                                .font(BlocTypography.caption).foregroundStyle(DesignColour.textSecondary)
                            Label("\(zone.betaCount)", systemImage: "link")
                                .font(BlocTypography.caption).foregroundStyle(DesignColour.textSecondary)
                            if let reset = zone.latestResetDate {
                                Text(verbatim: "·").foregroundStyle(DesignColour.textTertiary).font(BlocTypography.caption)
                                Text(reset.formatted(.relative(presentation: .named)))
                                    .font(BlocTypography.caption).foregroundStyle(DesignColour.textTertiary)
                            }
                        }
                    }
                    Spacer(minLength: DesignSpacing.small)
                    StatusChip(
                        title: L10n.wallAvailability(zone.availability),
                        systemImage: zone.availability == .active ? "checkmark.circle" : "pause.circle",
                        colour: zone.availability == .active ? DesignColour.success : DesignColour.warning
                    )
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DesignColour.textTertiary)
                }
                .padding(.horizontal, DesignSpacing.medium)
                .padding(.vertical, DesignSpacing.compact)
            }
            .accessibilityIdentifier("wall-zone-row-\(zone.id.rawValue)")
            Divider().opacity(0.5).padding(.horizontal, DesignSpacing.medium)
            let routes = viewModel.routesByZoneID[zone.id] ?? []
            if routes.isEmpty {
                Text(L10n.Gym.noActiveRoutes)
                    .font(BlocTypography.caption)
                    .foregroundStyle(DesignColour.textTertiary)
                    .padding(.horizontal, DesignSpacing.medium)
                    .padding(.vertical, DesignSpacing.small)
            } else {
                VStack(spacing: 0) {
                    ForEach(routes.prefix(5)) { route in
                        NavigationLink(value: route) {
                            GymRouteRow(route: route)
                        }
                        .accessibilityIdentifier("route-row-\(route.id.rawValue)")
                        if route.id != routes.prefix(5).last?.id {
                            Divider().opacity(0.4).padding(.leading, DesignSpacing.medium + 12)
                        }
                    }
                    if routes.count > 5 {
                        NavigationLink(value: zone) {
                            HStack {
                                Text(L10n.Gym.viewAllRoutes(count: routes.count))
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .font(BlocTypography.caption.weight(.semibold))
                            .foregroundStyle(BlocColor.opticBlue)
                            .padding(.horizontal, DesignSpacing.medium)
                            .padding(.vertical, DesignSpacing.small)
                        }
                    }
                }
                .padding(.bottom, DesignSpacing.small)
            }
        }
        .background(DesignColour.surfacePrimary, in: RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous).stroke(DesignColour.separator.opacity(0.5), lineWidth: 0.5) }
    }

    // MARK: - Facilities

    private var facilitiesSection: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.small) {
            Text(L10n.Gym.facilities)
                .font(DesignTypography.supporting.weight(.semibold))
                .foregroundStyle(DesignColour.textSecondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), alignment: .leading)], alignment: .leading, spacing: DesignSpacing.small) {
                ForEach(gym.facilities, id: \.self) { facility in
                    FacilityChip(facility: facility)
                }
            }
        }
        .padding(DesignSpacing.medium)
        .background(DesignColour.surfacePrimary, in: RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous).stroke(DesignColour.separator.opacity(0.5), lineWidth: 0.5) }
    }

    private var contactSection: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.small) {
            Text(L10n.Gym.contactDetails)
                .font(DesignTypography.supporting.weight(.semibold))
                .foregroundStyle(DesignColour.textSecondary)
            Text(L10n.Gym.contactFixtureMessage)
                .font(DesignTypography.supporting)
                .foregroundStyle(DesignColour.textSecondary)
            Divider().opacity(0.5)
            Text(L10n.Gym.operatingFixtureMessage)
                .font(BlocTypography.caption)
                .foregroundStyle(DesignColour.textTertiary)
        }
        .padding(DesignSpacing.medium)
        .background(DesignColour.surfacePrimary, in: RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous).stroke(DesignColour.separator.opacity(0.5), lineWidth: 0.5) }
    }
}

// MARK: - GymRouteRow (HoldDot shared with WallZone)

private struct GymRouteRow: View {
    let route: ClimbingRoute

    var body: some View {
        HStack(spacing: DesignSpacing.small) {
            HoldDot(colour: route.colour)
            HStack(spacing: 4) {
                Text(verbatim: route.colour)
                    .foregroundStyle(DesignColour.textPrimary)
                Text(verbatim: "·").foregroundStyle(DesignColour.textTertiary)
                Text(route.displayGrade?.displayName ?? String(localized: L10n.Grade.unknown))
                    .foregroundStyle(BlocColor.opticBlue)
                    .fontWeight(.semibold)
                if route.lifecycle == .archived {
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
        .padding(.horizontal, DesignSpacing.medium)
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

#Preview("Gym Detail — Loaded") {
    let environment = AppEnvironment.development()
    NavigationStack {
        GymDetailView(
            gym: DevelopmentFixtures.gyms[0],
            environment: environment,
            session: AppSession(environment: environment)
        )
    }
}

#Preview("Gym Detail — Empty") {
    let environment = AppEnvironment.development(scenario: .empty)
    NavigationStack {
        GymDetailView(
            gym: DevelopmentFixtures.gyms[0],
            environment: environment,
            session: AppSession(environment: environment)
        )
    }
}
