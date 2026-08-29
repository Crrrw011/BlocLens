import SwiftUI

struct RouteDetailView: View {
    let route: ClimbingRoute
    let environment: AppEnvironment
    @ObservedObject var session: AppSession

    @StateObject private var viewModel: RouteDetailViewModel
    @State private var betaRevealState: BetaRevealState = .hidden
    @State private var showsSafetyConfirmation = false
    @State private var showsLogbookDetails = false
    @State private var showsExternalHandoffNotice = false
    @State private var activeContributionSheet: RouteContributionSheet?
    @State private var pendingContributionSheet: RouteContributionSheet?
    @State private var reportBetaID: BetaLinkID?
    @State private var helpfulLinkIDs: Set<BetaLinkID> = []
    @State private var saveFeedbackTrigger = 0
    @State private var helpfulFeedbackTrigger = 0
    @State private var isEditRoutePresented = false
    @State private var isShareBetaPresented = false
    @State private var isSecondaryExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        route: ClimbingRoute,
        environment: AppEnvironment,
        session: AppSession,
        initialBetaRevealed: Bool = false
    ) {
        self.route = route
        self.environment = environment
        self.session = session
        _betaRevealState = State(initialValue: initialBetaRevealed ? .revealed : .hidden)
        _viewModel = StateObject(wrappedValue: RouteDetailViewModel(route: route, environment: environment))
    }

    private var isRouteCreator: Bool {
        guard let current = environment.currentUserID() else { return false }
        return route.createdBy == current
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                heroPhotoSection
                VStack(alignment: .leading, spacing: BlocSpacing.sectionGap) {
                    if route.lifecycle == .archived {
                        archivedBanner
                    } else if route.lifecycle == .temporarilyHidden {
                        moderationBanner
                    }
                    titleGroup
                    Divider().overlay(DesignColour.separator.opacity(0.6))
                    compactMetadataRow
                    mainActionsSection
                    betaPreviewRow
                    privateNoteSection
                    secondaryFold
                }
                .padding(.horizontal, DesignSpacing.medium)
                .padding(.top, DesignSpacing.medium)
                .padding(.bottom, DesignSpacing.large)
            }
        }
        .ignoresSafeArea(edges: .top)
        .navigationTitle(L10n.Route.detailTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isRouteCreator {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            isEditRoutePresented = true
                        } label: {
                            Label(L10n.Route.edit, systemImage: "pencil")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityIdentifier("route-more-button")
                }
            }
        }
        .sheet(isPresented: $isEditRoutePresented) {
            EditRouteView(environment: environment, session: session, route: route)
        }
        .sheet(isPresented: $isShareBetaPresented) {
            AddContributionView(action: .publishBetaLink, environment: environment, preselectedRoute: route)
        }
        .task { await viewModel.load(viewerProfile: session.authenticationState.profile) }
        .onChange(of: session.resumedIntent) { _, intent in
            guard let intent else { return }
            switch intent {
            case .revealBeta(let routeID) where routeID == route.id:
                session.consumeResumedIntent(intent)
                requestBetaRevealAfterAuthentication()
            case .saveLogbook(let routeID, let status) where routeID == route.id:
                session.consumeResumedIntent(intent)
                Task { await saveLogbook(status) }
            case .helpful(let betaID):
                session.consumeResumedIntent(intent)
                markHelpful(betaID)
            case .account:
                guard let pendingContributionSheet else { break }
                session.consumeResumedIntent(.account)
                self.pendingContributionSheet = nil
                activeContributionSheet = pendingContributionSheet
            default:
                break
            }
        }
        .alert(L10n.Beta.safetyTitle, isPresented: $showsSafetyConfirmation) {
            Button(L10n.Common.continueButton) {
                session.hasAcknowledgedRevealSafety = true
                revealBeta()
            }
            .accessibilityIdentifier("acknowledge-beta-safety-button")
            Button(L10n.Common.cancel, role: .cancel) {}
        } message: {
            Text(L10n.Beta.safetyMessage)
        }
        .alert(L10n.Beta.externalHandoffTitle, isPresented: $showsExternalHandoffNotice) {
            Button(L10n.Common.ok, role: .cancel) {}
        } message: {
            Text(L10n.Beta.externalHandoffMessage)
        }
        .alert(
            L10n.State.errorTitle,
            isPresented: Binding(
                get: { viewModel.saveError != nil },
                set: { isPresented in
                    if !isPresented { viewModel.clearSaveError() }
                }
            )
        ) {
            Button(L10n.Common.ok, role: .cancel) {}
        } message: {
            Text(L10n.State.fixtureErrorMessage)
        }
        .sheet(isPresented: $showsLogbookDetails) {
            if let entry = viewModel.logbookEntry {
                LogbookDetailsSheet(entry: entry) { details in
                    Task {
                        if await viewModel.update(details: details) != nil {
                            showsLogbookDetails = false
                        }
                    }
                }
            }
        }
        .sheet(item: $activeContributionSheet) { sheet in
            contributionSheet(sheet)
        }
        .alert(
            Text(verbatim: "Contribution saved"),
            isPresented: Binding(
                get: { viewModel.contributionMessage != nil },
                set: { if !$0 { viewModel.clearContributionMessage() } }
            )
        ) {
            Button { viewModel.clearContributionMessage() } label: { Text(verbatim: "OK") }
        } message: {
            Text(verbatim: viewModel.contributionMessage ?? "")
        }
        .sensoryFeedback(.success, trigger: saveFeedbackTrigger)
        .sensoryFeedback(.success, trigger: helpfulFeedbackTrigger)
    }

    // MARK: - Hero L0

    private var heroPhotoSection: some View {
        ZStack(alignment: .bottomLeading) {
            heroWallFill
            LinearGradient(colors: [.clear, Color.black.opacity(0.30)], startPoint: .top, endPoint: .bottom)
            floatingCapsules
                .padding(.horizontal, DesignSpacing.medium)
                .padding(.bottom, DesignSpacing.medium)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(4 / 3, contentMode: .fit)
        .clipped()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: "\(route.colour) \(String(localized: L10n.terrain(route.terrain))) \(route.displayGrade?.displayName ?? "")"))
    }

    private var heroWallFill: some View {
        // Placeholder wall photo using hold colour + shape shape — full-bleed, no card
        ZStack {
            holdColorFill
            // Subtle texture: diagonal hold pattern using RouteColourSwatch color at low opacity
            Rectangle().fill(Color.white.opacity(0.04))
        }
    }

    private var holdColorFill: some View {
        let token = BlocColor.routePalette.first(where: { $0.name.lowercased() == route.colour.lowercased() }) ?? BlocColor.grey
        return token.color
    }

    private var floatingCapsules: some View {
        HStack(spacing: DesignSpacing.small) {
            gradeCapsuleSolid
            statusCapsuleGlass
            resetCapsuleGlass
            Spacer(minLength: 0)
        }
    }

    private var gradeCapsuleSolid: some View {
        Text(route.displayGrade?.displayName ?? String(localized: L10n.Grade.unknown))
            .font(BlocTypography.grade)
            .foregroundStyle(holdTextColor)
            .padding(.horizontal, 14)
            .frame(minHeight: 32)
            .background(holdCapsuleBackground, in: Capsule())
            .overlay { Capsule().stroke(Color.black.opacity(0.08), lineWidth: 0.5) }
            .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
            .accessibilityIdentifier("hero-grade")
            .accessibilityLabel(Text(verbatim: route.displayGrade?.displayName ?? "Unknown"))
    }

    private var holdTextColor: Color {
        let token = BlocColor.routePalette.first(where: { $0.name.lowercased() == route.colour.lowercased() }) ?? BlocColor.grey
        return token.textColor
    }

    private var holdCapsuleBackground: Color {
        // Solid — wall as interface, grade is solid not glass (Flighty status first-class)
        Color(uiColor: .systemBackground)
    }

    private var statusCapsuleGlass: some View {
        let title: LocalizedStringResource = viewModel.logbookEntry.map { L10n.logbookStatus($0.status) } ?? lifecycleFallbackTitle
        return Label(title, systemImage: statusIcon)
            .font(BlocTypography.status)
            .foregroundStyle(.white)
            .padding(.horizontal, BlocSpacing.compact)
            .frame(minHeight: 28)
            .background(glassCapsuleBackground)
            .overlay { Capsule().stroke(.white.opacity(0.18), lineWidth: 0.5) }
            .shadow(color: .black.opacity(0.16), radius: 8, y: 4)
            .accessibilityIdentifier("hero-status")
    }

    private var lifecycleFallbackTitle: LocalizedStringResource {
        switch route.lifecycle {
        case .archived: L10n.Route.lifecycleArchived
        case .temporarilyHidden: L10n.Route.hiddenReviewMessage
        case .active: L10n.Route.lifecycleActive
        }
    }

    private var statusIcon: String {
        if let status = viewModel.logbookEntry?.status {
            switch status {
            case .wantToTry: "bookmark"
            case .projecting: "hammer"
            case .sent: "checkmark.circle"
            case .flash: "bolt"
            }
        } else {
            switch route.lifecycle {
            case .archived: "archivebox"
            case .temporarilyHidden: "eye.slash"
            case .active: "checkmark.circle"
            }
        }
    }

    private var resetCapsuleGlass: some View {
        Label(resetText, systemImage: "arrow.clockwise")
            .font(BlocTypography.status)
            .foregroundStyle(.white)
            .padding(.horizontal, BlocSpacing.compact)
            .frame(minHeight: 28)
            .background(glassCapsuleBackground)
            .overlay { Capsule().stroke(.white.opacity(0.18), lineWidth: 0.5) }
            .shadow(color: .black.opacity(0.16), radius: 8, y: 4)
            .accessibilityIdentifier("hero-reset")
    }

    private var resetText: String {
        if let archive = route.expectedArchiveDate {
            let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: archive)).day ?? 0
            if days <= 0 { return String(localized: "Reset today") }
            if days == 1 { return "Reset 1d" }
            return "Reset \(days)d"
        }
        if let reset = route.resetDate {
            let days = Calendar.current.dateComponents([.day], from: reset, to: Date()).day ?? 0
            if days < 7 { return "Fresh \(max(1, 7 - days))d" }
            return reset.formatted(date: .abbreviated, time: .omitted)
        }
        return "Reset —"
    }

    @ViewBuilder
    private var glassCapsuleBackground: some View {
        if #available(iOS 26.0, *) {
            Capsule().fill(.ultraThinMaterial).overlay { Capsule().fill(BlocColor.opticBlueTint.opacity(0.12)) }
                .glassEffect(.regular.tint(BlocColor.opticBlueTint).interactive(false), in: Capsule())
        } else {
            Capsule().fill(.ultraThinMaterial).overlay { Capsule().fill(Color.black.opacity(0.18)) }
        }
    }

    // MARK: - Title group no card

    private var titleGroup: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.xSmall) {
            Text(verbatim: "\(route.colour) \(String(localized: L10n.terrain(route.terrain)))")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(DesignColour.textPrimary)
                .minimumScaleFactor(0.85)
                .lineLimit(1)
            HStack(spacing: DesignSpacing.small) {
                if let wallZone = viewModel.wallZone {
                    Label(wallZone.name, systemImage: "square.stack.3d.up")
                        .accessibilityIdentifier("hero-location")
                } else {
                    Label(route.gymID.rawValue, systemImage: "mappin")
                        .accessibilityIdentifier("hero-location")
                }
                Text(verbatim: "·")
                Text(route.displayGrade?.displayName ?? String(localized: L10n.Grade.unknown))
                    .font(BlocTypography.grade)
                    .foregroundStyle(BlocColor.opticBlue)
            }
            .font(DesignTypography.supporting)
            .foregroundStyle(DesignColour.textSecondary)
            .lineLimit(1)
            if let reset = route.resetDate {
                Text(reset.formatted(date: .abbreviated, time: .omitted))
                    .font(BlocTypography.caption)
                    .foregroundStyle(DesignColour.textTertiary)
            }
            if let archiveDate = route.expectedArchiveDate, route.isArchiveDateEstimated {
                Label {
                    Text(L10n.Route.estimatedArchive) + Text(verbatim: " \(archiveDate.formatted(date: .abbreviated, time: .omitted))")
                } icon: {
                    Image(systemName: "calendar.badge.exclamationmark")
                }
                .font(BlocTypography.caption)
                .foregroundStyle(DesignColour.warning)
            }
        }
    }

    // MARK: - Compact metadata row

    private var compactMetadataRow: some View {
        let terrain = String(localized: L10n.terrain(route.terrain))
        let style = route.styles.first.map { String(localized: L10n.routeStyle($0)) } ?? String(localized: L10n.routeStyle(.staticMovement))
        let community = route.communityGradeSummary.displayGrade?.displayName ?? "—"
        // ponytail: 25° hardcoded, replace with wallZone.angle when model adds it
        return Text(verbatim: "\(terrain) · \(style) · 25° · Community \(community)")
            .font(BlocTypography.metadata)
            .foregroundStyle(DesignColour.textSecondary)
            .lineLimit(1)
            .truncationMode(.tail)
    }

    // MARK: - Main actions capsule + BetaPreview + private note

    private var mainActionsSection: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.small) {
            glassSegmentedLogbook
            if session.authenticationState.isSignedIn, let entry = viewModel.logbookEntry {
                Label(
                    entry.syncState == .queued ? L10n.Logbook.queued : L10n.Logbook.savedPrivate,
                    systemImage: entry.syncState == .queued ? "clock.arrow.circlepath" : "lock.fill"
                )
                .font(BlocTypography.caption)
                .foregroundStyle(entry.syncState == .queued ? DesignColour.warning : DesignColour.success)
            }
        }
    }

    private var glassSegmentedLogbook: some View {
        HStack(spacing: 2) {
            ForEach(LogbookStatus.allCases, id: \.self) { status in
                let isSelected = viewModel.logbookEntry?.status == status
                Button {
                    BlocHaptics.lightImpact()
                    Task { await saveLogbook(status) }
                } label: {
                    Text(L10n.logbookStatus(status))
                        .font(BlocTypography.status)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(isSelected ? .white : DesignColour.textPrimary)
                        .background(
                            isSelected ? BlocColor.opticBlue : Color.clear,
                            in: Capsule()
                        )
                }
                .accessibilityIdentifier("logbook-status-\(status.rawValue)")
                .accessibilityValue(isSelected ? L10n.Common.selected : L10n.Common.notSelected)
            }
        }
        .padding(4)
        .background(glassSegmentBackground)
        .overlay { Capsule().stroke(.white.opacity(0.12), lineWidth: 0.5) }
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
    }

    @ViewBuilder
    private var glassSegmentBackground: some View {
        if #available(iOS 26.0, *) {
            Capsule().fill(.ultraThinMaterial)
                .glassEffect(.regular.tint(BlocColor.opticBlueTint).interactive(false), in: Capsule())
        } else {
            Capsule().fill(Color(uiColor: .secondarySystemBackground))
        }
    }

    @ViewBuilder
    private var betaPreviewRow: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.small) {
            HStack(spacing: DesignSpacing.compact) {
                betaThumbnail
                VStack(alignment: .leading, spacing: 2) {
                    if let link = firstBetaLink {
                        Text(domain(for: link))
                            .font(DesignTypography.caption)
                            .foregroundStyle(DesignColour.textSecondary)
                            .lineLimit(1)
                        Text(link.originalAuthor)
                            .font(BlocTypography.caption)
                            .foregroundStyle(DesignColour.textPrimary)
                            .lineLimit(1)
                    } else {
                        Text(L10n.Beta.noBetaTitle)
                            .font(DesignTypography.caption)
                            .foregroundStyle(DesignColour.textSecondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Label("\(route.betaCount)", systemImage: "link")
                        .font(BlocTypography.status)
                        .foregroundStyle(DesignColour.textSecondary)
                        .accessibilityIdentifier("hero-beta-count")
                    if let link = firstBetaLink {
                        Text(verbatim: "\(link.helpfulCount) helpful")
                            .font(BlocTypography.caption)
                            .foregroundStyle(DesignColour.textTertiary)
                    }
                }
            }
            .padding(DesignSpacing.small)
            .background(DesignColour.surfacePrimary, in: RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous).stroke(DesignColour.separator.opacity(0.5), lineWidth: 0.5) }

            // Hidden beta reveal CTA remains functional
            if !betaRevealState.isRevealed {
                Button(L10n.Beta.reveal) {
                    if session.requireAuthentication(for: .revealBeta(routeID: route.id)) {
                        requestBetaRevealAfterAuthentication()
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("reveal-beta-button")
            } else {
                revealedBetaContent
            }
        }
    }

    private var betaThumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(DesignColour.surfaceElevated)
            if let link = firstBetaLink {
                Image(systemName: platformIcon(link.platform))
                    .foregroundStyle(DesignColour.textSecondary)
            } else {
                Image(systemName: "link.badge.plus").foregroundStyle(DesignColour.opticBlue)
            }
        }
        .frame(width: 48, height: 48)
        .overlay { RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(DesignColour.separator.opacity(0.5), lineWidth: 0.5) }
    }

    private var firstBetaLink: BetaLink? {
        switch viewModel.betaState {
        case .loaded(let links), .offlineWithCache(let links): links.first
        default: nil
        }
    }

    private func domain(for link: BetaLink) -> String {
        link.sourceURL.host ?? String(localized: L10n.betaPlatform(link.platform))
    }

    private func platformIcon(_ platform: BetaPlatform) -> String {
        switch platform {
        case .youtube: "play.rectangle"
        case .instagram: "camera"
        case .tiktok: "music.note"
        case .vimeo: "video"
        case .other: "link"
        }
    }

    private var privateNoteSection: some View {
        Group {
            if let entry = viewModel.logbookEntry, let note = entry.privateNote, !note.isEmpty {
                VStack(alignment: .leading, spacing: DesignSpacing.xSmall) {
                    Label(L10n.Logbook.privateNote, systemImage: "lock.fill")
                        .font(BlocTypography.caption)
                        .foregroundStyle(DesignColour.textSecondary)
                    Text(verbatim: note)
                        .font(DesignTypography.supporting)
                        .foregroundStyle(DesignColour.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DesignSpacing.medium)
                .background(DesignColour.surfacePrimary, in: RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous).stroke(DesignColour.separator.opacity(0.5), lineWidth: 0.5) }
            } else if viewModel.logbookEntry != nil {
                Button {
                    showsLogbookDetails = true
                } label: {
                    Label(L10n.Logbook.privateNotePrompt, systemImage: "square.and.pencil")
                }
                .font(BlocTypography.caption)
                .foregroundStyle(DesignColour.textSecondary)
            }
        }
    }

    // MARK: - Secondary fold

    private var secondaryFold: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.medium) {
            if !isSecondaryExpanded {
                Button {
                    withAnimation(DesignMotion.animation(DesignMotion.stateChange, reduceMotion: reduceMotion)) {
                        isSecondaryExpanded = true
                    }
                } label: {
                    HStack {
                        Text(verbatim: "View all details")
                        Spacer()
                        Image(systemName: "chevron.down")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BlocColor.opticBlue)
                }
                .accessibilityIdentifier("view-all-details-button")
                // Collapsed summary keeps glanceable density
                compactSecondarySummary
            } else {
                Button {
                    withAnimation(DesignMotion.animation(DesignMotion.stateChange, reduceMotion: reduceMotion)) {
                        isSecondaryExpanded = false
                    }
                } label: {
                    HStack {
                        Text(verbatim: "Show less")
                        Spacer()
                        Image(systemName: "chevron.up")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BlocColor.opticBlue)
                }
                .accessibilityIdentifier("show-less-button")
                Divider()
                communityGradeSection
                commentsSection
                reportAndCorrectionSection
            }
        }
        .padding(DesignSpacing.medium)
        .background(DesignColour.surfacePrimary, in: RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous).stroke(DesignColour.separator.opacity(0.5), lineWidth: 0.5) }
    }

    private var compactSecondarySummary: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.xSmall) {
            if let grade = route.communityGradeSummary.displayGrade {
                HStack {
                    Text(L10n.Route.communityGradeTitle).font(BlocTypography.caption).foregroundStyle(DesignColour.textSecondary)
                    Spacer()
                    Text(grade.displayName).font(BlocTypography.grade)
                }
            }
            HStack {
                Text(verbatim: "Comments")
                    .font(BlocTypography.caption)
                    .foregroundStyle(DesignColour.textSecondary)
                Spacer()
                Text(verbatim: "\(viewModel.comments.count)")
                    .font(BlocTypography.status)
                    .foregroundStyle(DesignColour.textPrimary)
            }
        }
    }

    // MARK: - Preserved sections (now inside fold or main)

    private var archivedBanner: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.small) {
            RouteLifecycleIndicator(lifecycle: .archived)
            Text(L10n.Route.archivedHistoryMessage)
                .font(DesignTypography.supporting)
                .foregroundStyle(DesignColour.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSpacing.medium)
        .background(DesignColour.surfaceElevated, in: RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous).stroke(DesignColour.separator.opacity(0.42), lineWidth: 0.5) }
    }

    private var moderationBanner: some View {
        Label(L10n.Route.hiddenReviewMessage, systemImage: "eye.slash")
            .font(.subheadline)
            .foregroundStyle(DesignColour.destructive)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignSpacing.medium)
            .background(DesignColour.surfacePrimary, in: RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous).stroke(DesignColour.separator.opacity(0.5), lineWidth: 0.5) }
    }

    @ViewBuilder
    private var revealedBetaContent: some View {
        switch viewModel.betaState {
        case .initial, .loading:
            LoadingStateView()
        case .loaded(let links), .offlineWithCache(let links):
            ForEach(links) { link in
                BetaLinkCard(
                    link: link,
                    isHelpful: helpfulLinkIDs.contains(link.id),
                    openOriginal: { showsExternalHandoffNotice = true },
                    markHelpful: { markHelpful(link.id) },
                    reportIssue: {
                        reportBetaID = link.id
                        requestContribution(.reportBeta)
                    }
                )
            }
            ForEach(viewModel.brokenLinks) { link in
                Label(L10n.Beta.brokenLink, systemImage: "link.badge.plus")
                    .foregroundStyle(DesignColour.destructive)
                    .accessibilityLabel(
                        "\(String(localized: L10n.Beta.brokenLink)): \(String(localized: L10n.betaPlatform(link.platform)))"
                    )
            }
        case .empty:
            Text(L10n.Beta.emptyMessage)
                .foregroundStyle(DesignColour.secondaryText)
        case .error:
            Text(L10n.State.fixtureErrorMessage)
                .foregroundStyle(DesignColour.destructive)
        case .offlineWithoutCache:
            Text(L10n.Beta.offlineMessage)
                .foregroundStyle(DesignColour.secondaryText)
        }
    }

    private var communityGradeSection: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.small) {
            Text(L10n.Route.communityGradeTitle).font(.title3.bold())
            if let grade = route.communityGradeSummary.displayGrade {
                Text(grade.displayName).font(.title2.bold())
                Text(route.communityGradeSummary.voteCount, format: .number) + Text(L10n.Route.validVotesSuffix)
                    .font(.caption)
                    .foregroundStyle(DesignColour.secondaryText)
            } else {
                Text(L10n.Route.communityGradeHidden)
                    .foregroundStyle(DesignColour.secondaryText)
                Text(route.communityGradeSummary.voteCount, format: .number) + Text(L10n.Route.validVotesSuffix)
                    .font(.caption)
                    .foregroundStyle(DesignColour.tertiaryText)
            }
        }
    }

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.small) {
            Text(L10n.Route.commentsTitle).font(.title3.bold())
            if viewModel.comments.isEmpty {
                Text(verbatim: "No comments yet. Keep comments practical and specific to this beta.")
                    .foregroundStyle(DesignColour.secondaryText)
            } else {
                ForEach(viewModel.comments) { comment in
                    VStack(alignment: .leading, spacing: DesignSpacing.xSmall) {
                        HStack {
                            Text(verbatim: comment.officialGymID == nil ? "Climber" : "Verified gym")
                                .font(.caption.weight(.semibold))
                            Spacer()
                            Text(verbatim: comment.createdAt.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(DesignColour.textTertiary)
                        }
                        Text(verbatim: comment.body)
                    }
                    if comment.id != viewModel.comments.last?.id { Divider() }
                }
            }
            Button {
                requestContribution(.comment)
            } label: {
                Label { Text(verbatim: "Add comment") } icon: { Image(systemName: "text.bubble") }
            }
            .buttonStyle(CompactActionButtonStyle())
        }
    }

    private var reportAndCorrectionSection: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.small) {
            SectionTitle(title: L10n.Route.accuracyTitle)
            Button(L10n.Route.suggestCorrection) {
                requestContribution(.correction)
            }
            .buttonStyle(SecondaryButtonStyle())
            Button(L10n.Route.reportRoute) {
                requestContribution(.reportRoute)
            }
            .buttonStyle(CompactActionButtonStyle())
            Button {
                requestContribution(.reset)
            } label: {
                Label { Text(verbatim: "Confirm wall reset") } icon: { Image(systemName: "arrow.clockwise") }
            }
            .buttonStyle(CompactActionButtonStyle())
        }
    }

    private func requestBetaRevealAfterAuthentication() {
        if session.hasAcknowledgedRevealSafety {
            revealBeta()
        } else {
            showsSafetyConfirmation = true
        }
    }

    private func saveLogbook(_ status: LogbookStatus) async {
        if await viewModel.save(status: status) != nil {
            saveFeedbackTrigger += 1
            showsLogbookDetails = true
        }
    }

    private func revealBeta() {
        withAnimation(DesignMotion.animation(DesignMotion.reveal, reduceMotion: reduceMotion)) {
            betaRevealState.reveal()
        }
    }

    private func markHelpful(_ betaID: BetaLinkID) {
        guard session.requireAuthentication(for: .helpful(betaID: betaID)) else { return }
        guard !helpfulLinkIDs.contains(betaID) else { return }
        Task {
            if await viewModel.markHelpful(betaID: betaID) {
                helpfulLinkIDs.insert(betaID)
                helpfulFeedbackTrigger += 1
                await session.refreshRoleContext()
            }
        }
    }

    private func requestContribution(_ sheet: RouteContributionSheet) {
        pendingContributionSheet = sheet
        if session.requireAuthentication(for: .account) {
            pendingContributionSheet = nil
            activeContributionSheet = sheet
        }
    }

    @ViewBuilder
    private func contributionSheet(_ sheet: RouteContributionSheet) -> some View {
        switch sheet {
        case .photo:
            RoutePhotoMetadataSheet(
                username: session.authenticationState.profile?.username ?? "Current account",
                submit: { await viewModel.addPhoto(url: $0) }
            )
        case .correction:
            RouteCorrectionSheet { issue, proposedValue, explanation in
                await viewModel.submitCorrection(
                    issue: issue, proposedValue: proposedValue, explanation: explanation
                )
            }
        case .comment:
            if let betaID = firstVisibleBetaID {
                BetaCommentSheet { body in
                    let officialGymID = session.roleContext.manages(gymID: route.gymID) ? route.gymID : nil
                    return await viewModel.addComment(
                        betaID: betaID, body: body, officialGymID: officialGymID
                    )
                }
            } else {
                NavigationStack {
                    VStack(spacing: DesignSpacing.medium) {
                        Image(systemName: "text.bubble")
                            .font(.largeTitle)
                        Text(verbatim: "No beta link available").font(.title2.bold())
                        Text(verbatim: "Comments belong to a beta link. Share a public beta link first.")
                            .foregroundStyle(DesignColour.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
            }
        case .reportRoute:
            ContentReportSheet { category, details in
                await viewModel.report(
                    targetType: .route, targetID: route.id.rawValue,
                    category: category, details: details
                )
            }
        case .reportBeta:
            ContentReportSheet { category, details in
                guard let reportBetaID else { return false }
                return await viewModel.report(
                    targetType: .betaLink, targetID: reportBetaID.rawValue,
                    category: category, details: details
                )
            }
        case .reset:
            ResetConfirmationSheet { await viewModel.confirmReset() }
        }
    }

    private var firstVisibleBetaID: BetaLinkID? {
        switch viewModel.betaState {
        case .loaded(let links), .offlineWithCache(let links): links.first?.id
        default: nil
        }
    }
}

private struct BetaLinkCard: View {
    let link: BetaLink
    let isHelpful: Bool
    let openOriginal: () -> Void
    let markHelpful: () -> Void
    let reportIssue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.small) {
            betaMetadataRow(
                L10n.Beta.platform,
                value: String(localized: L10n.betaPlatform(link.platform))
            )
            betaMetadataRow(L10n.Beta.originalAuthor, value: link.originalAuthor)
            FlowLayout(tags: link.tags)
            HelpfulCountView(count: link.helpfulCount + (isHelpful ? 1 : 0))

            if link.embedSupport == .supported {
                BetaVideoPlayerView(url: link.sourceURL)
                    .frame(height: 210)
                    .clipShape(RoundedRectangle(cornerRadius: DesignRadius.small))
            } else {
                Button(L10n.Beta.openOriginalPost, action: openOriginal)
                    .buttonStyle(SecondaryButtonStyle())
            }
            HStack {
                Button(action: markHelpful) {
                    Label(L10n.Beta.helpful, systemImage: isHelpful ? "hand.thumbsup.fill" : "hand.thumbsup")
                }
                    .buttonStyle(CompactActionButtonStyle())
                    .disabled(isHelpful)
                Button(L10n.Beta.reportIssue, action: reportIssue)
                    .buttonStyle(CompactActionButtonStyle())
            }
        }
        .padding(.vertical, DesignSpacing.small)
        Divider()
    }

    private func betaMetadataRow(_ label: LocalizedStringResource, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(DesignColour.secondaryText)
        }
    }
}

#Preview("Route Detail — Hidden Beta") {
    let environment = AppEnvironment.development(authenticationState: .signedIn(DevelopmentFixtures.mockProfile))
    let session = AppSession(environment: environment)
    NavigationStack {
        RouteDetailView(
            route: DevelopmentFixtures.routes[0],
            environment: environment,
            session: session
        )
    }
    .task { await session.load() }
}

#Preview("Route Detail — Revealed and Broken Beta") {
    let environment = AppEnvironment.development(authenticationState: .signedIn(DevelopmentFixtures.mockProfile))
    let session = AppSession(environment: environment)
    NavigationStack {
        RouteDetailView(
            route: DevelopmentFixtures.routes.first { $0.id == "west-end-slab-r1" } ?? DevelopmentFixtures.routes[0],
            environment: environment,
            session: session,
            initialBetaRevealed: true
        )
    }
    .task { await session.load() }
    .preferredColorScheme(.dark)
}

private struct FlowLayout: View {
    let tags: [BetaTag]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(tags, id: \.self) { tag in
                    Text(L10n.betaTag(tag))
                        .font(.caption)
                        .padding(.horizontal, DesignSpacing.small)
                        .padding(.vertical, DesignSpacing.xSmall)
                        .background(DesignColour.surface, in: Capsule())
                }
            }
        }
    }

}
