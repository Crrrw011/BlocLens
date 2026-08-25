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
    @State private var showsIssueMenu = false
    @State private var selectedIssue: LocalizedStringResource?
    @State private var helpfulLinkIDs: Set<BetaLinkID> = []
    @State private var saveFeedbackTrigger = 0
    @State private var helpfulFeedbackTrigger = 0
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSpacing.large) {
                if route.lifecycle == .archived {
                    archivedBanner
                } else if route.lifecycle == .temporarilyHidden {
                    moderationBanner
                }
                identitySection
                quickLogbookSection
                betaSection
                communityGradeSection
                commentsPlaceholder
                reportAndCorrectionSection
            }
            .padding()
        }
        .navigationTitle(L10n.Route.detailTitle)
        .navigationBarTitleDisplayMode(.inline)
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
        .confirmationDialog(L10n.Beta.reportIssue, isPresented: $showsIssueMenu) {
            Button(L10n.Beta.wrongRoute) { selectedIssue = L10n.Beta.wrongRoute }
            Button(L10n.Beta.brokenLink) { selectedIssue = L10n.Beta.brokenLink }
            Button(L10n.Beta.unsafeContent, role: .destructive) { selectedIssue = L10n.Beta.unsafeContent }
            Button(L10n.Common.cancel, role: .cancel) {}
        }
        .alert(L10n.Beta.feedbackPlaceholderTitle, isPresented: Binding(
            get: { selectedIssue != nil },
            set: { if !$0 { selectedIssue = nil } }
        )) {
            Button(L10n.Common.ok, role: .cancel) {}
        } message: {
            Text(L10n.Beta.feedbackPlaceholderMessage)
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
        .sensoryFeedback(.success, trigger: saveFeedbackTrigger)
        .sensoryFeedback(.success, trigger: helpfulFeedbackTrigger)
    }

    private var archivedBanner: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.small) {
            StatusChip(title: L10n.Route.archived, systemImage: "archivebox.fill", colour: DesignColour.archived)
            Text(L10n.Route.archivedHistoryMessage)
                .font(DesignTypography.supporting)
                .foregroundStyle(DesignColour.textSecondary)
        }
        .cardStyle(elevated: true)
    }

    private var moderationBanner: some View {
        Label(L10n.Route.hiddenReviewMessage, systemImage: "eye.slash")
            .font(.subheadline)
            .foregroundStyle(DesignColour.destructive)
            .cardStyle()
    }

    private var identitySection: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.medium) {
            RoundedRectangle(cornerRadius: DesignRadius.large)
                .fill(DesignColour.surfacePrimary)
                .aspectRatio(16 / 10, contentMode: .fit)
                .overlay {
                    VStack(spacing: DesignSpacing.small) {
                        RouteColourSwatch(colourOrTag: route.colourOrTag, size: 64)
                        Text(L10n.Route.photoPlaceholder)
                            .font(DesignTypography.cardTitle)
                        Text(route.colourOrTag)
                            .font(DesignTypography.supporting)
                            .foregroundStyle(DesignColour.textSecondary)
                    }
                }
                .overlay { RoundedRectangle(cornerRadius: DesignRadius.large).stroke(DesignColour.separator.opacity(0.5), lineWidth: 0.5) }

            if session.isContributionPromptVisible("route-photo-\(route.id.rawValue)") {
                ContributionPromptView(
                    title: L10n.Route.photoContributionTitle,
                    message: L10n.Route.photoContributionMessage,
                    primaryActionTitle: L10n.Route.addPhoto,
                    primaryAction: { _ = session.requireAuthentication(for: .account) },
                    dismissAction: { session.dismissContributionPrompt("route-photo-\(route.id.rawValue)") }
                )
            }

            HStack(alignment: .center, spacing: DesignSpacing.compact) {
                RouteColourSwatch(colourOrTag: route.colourOrTag, size: 52)
                Text(route.colourOrTag).font(DesignTypography.largeScreenTitle)
                Spacer()
            }
            HStack(spacing: DesignSpacing.small) {
                GradeChip(grade: route.officialGrade, label: L10n.Route.gymGrade)
                if let community = route.communityGradeSummary.displayGrade {
                    GradeChip(grade: community, label: L10n.Route.communityGradeTitle)
                }
            }
            if let wallZone = viewModel.wallZone {
                Label(wallZone.name, systemImage: "square.stack.3d.up")
                    .font(.subheadline)
                    .foregroundStyle(DesignColour.secondaryText)
            }
            if let reset = route.resetDate {
                Label(reset.formatted(date: .long, time: .omitted), systemImage: "arrow.clockwise")
                    .font(.caption)
                    .foregroundStyle(DesignColour.secondaryText)
            }
            if let archiveDate = route.expectedArchiveDate, route.isArchiveDateEstimated {
                VStack(alignment: .leading, spacing: DesignSpacing.xSmall) {
                    Label {
                        Text(L10n.Route.estimatedArchive) + Text(verbatim: " \(archiveDate.formatted(date: .abbreviated, time: .omitted))")
                    } icon: {
                        Image(systemName: "calendar.badge.exclamationmark")
                    }
                    Text(L10n.Route.estimateOnly)
                        .font(.caption2)
                }
                .font(.caption)
                .foregroundStyle(DesignColour.warning)
            }
        }
    }

    private var quickLogbookSection: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.medium) {
            SectionHeader(title: L10n.Logbook.quickStateTitle, supportingText: L10n.Logbook.privateByDefaultMessage)
            LogbookStatusControl(
                selection: session.authenticationState.isSignedIn ? viewModel.logbookEntry?.status : nil,
                isEnabled: true
            ) { status in
                if session.requireAuthentication(for: .saveLogbook(routeID: route.id, status: status)) {
                    Task { await saveLogbook(status) }
                }
            }
            if session.authenticationState.isSignedIn, let entry = viewModel.logbookEntry {
                Label(
                    entry.syncState == .queued ? L10n.Logbook.queued : L10n.Logbook.savedPrivate,
                    systemImage: entry.syncState == .queued ? "clock.arrow.circlepath" : "lock.fill"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(entry.syncState == .queued ? DesignColour.warning : DesignColour.success)
            }
        }
        .cardStyle()
    }

    private var betaSection: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.medium) {
            SectionHeader(title: L10n.Beta.title, supportingText: L10n.Beta.hiddenUntilReveal)
            if !betaRevealState.isRevealed {
                ZStack {
                    RouteColourSwatch(colourOrTag: route.colourOrTag, size: 112)
                        .blur(radius: 20)
                        .scaleEffect(1.8)
                        .opacity(0.62)
                    Rectangle().fill(.ultraThinMaterial)
                    VStack(spacing: DesignSpacing.small) {
                        Image(systemName: "eye.slash.fill").font(.title2)
                        Text(L10n.Beta.hiddenUntilReveal).font(.headline)
                    }
                    .foregroundStyle(DesignColour.textPrimary)
                }
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: DesignRadius.medium))

                hiddenBetaMetadata

                Button(L10n.Beta.reveal) {
                    if session.requireAuthentication(for: .revealBeta(routeID: route.id)) {
                        requestBetaRevealAfterAuthentication()
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("reveal-beta-button")
            } else {
                revealedBetaContent
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .cardStyle()
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
                    reportIssue: { showsIssueMenu = true }
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
        .cardStyle()
    }

    private var commentsPlaceholder: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.small) {
            Text(L10n.Route.commentsTitle).font(.title3.bold())
            Text(L10n.Route.commentsPlaceholder)
                .foregroundStyle(DesignColour.secondaryText)
        }
        .cardStyle()
    }

    private var reportAndCorrectionSection: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.small) {
            SectionTitle(title: L10n.Route.accuracyTitle)
            Button(L10n.Route.suggestCorrection) {
                _ = session.requireAuthentication(for: .account)
            }
            .buttonStyle(SecondaryButtonStyle())
            Button(L10n.Route.reportRoute) {
                _ = session.requireAuthentication(for: .account)
            }
            .buttonStyle(CompactActionButtonStyle())
        }
        .cardStyle()
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

    private var hiddenBetaMetadata: some View {
        Group {
            if case .loaded(let links) = viewModel.betaState, let link = links.first {
                HStack(spacing: DesignSpacing.compact) {
                    Label(L10n.betaPlatform(link.platform), systemImage: "play.rectangle")
                    Text(link.originalAuthor)
                    Spacer()
                    HelpfulCountView(count: link.helpfulCount)
                }
                .font(DesignTypography.caption)
                .foregroundStyle(DesignColour.textSecondary)
                FlowLayout(tags: link.tags)
            }
        }
    }

    private func revealBeta() {
        withAnimation(DesignMotion.animation(DesignMotion.reveal, reduceMotion: reduceMotion)) {
            betaRevealState.reveal()
        }
    }

    private func markHelpful(_ betaID: BetaLinkID) {
        guard session.requireAuthentication(for: .helpful(betaID: betaID)) else { return }
        guard helpfulLinkIDs.insert(betaID).inserted else { return }
        helpfulFeedbackTrigger += 1
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
                RoundedRectangle(cornerRadius: DesignRadius.small)
                    .fill(DesignColour.opticBlue.opacity(0.1))
                    .frame(height: 110)
                    .overlay {
                        VStack {
                            Image(systemName: "play.rectangle")
                            Text(L10n.Beta.embedPlaceholder)
                        }
                        .foregroundStyle(DesignColour.opticBlue)
                    }
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
