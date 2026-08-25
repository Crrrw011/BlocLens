import SwiftUI

struct RouteDetailView: View {
    let route: ClimbingRoute
    let environment: AppEnvironment
    @ObservedObject var session: AppSession

    @StateObject private var viewModel: RouteDetailViewModel
    @State private var isBetaRevealed = false
    @State private var showsSafetyConfirmation = false
    @State private var showsLogbookDetails = false

    init(route: ClimbingRoute, environment: AppEnvironment, session: AppSession) {
        self.route = route
        self.environment = environment
        self.session = session
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
            }
            .padding()
        }
        .navigationTitle(L10n.Route.detailTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .alert(L10n.Beta.safetyTitle, isPresented: $showsSafetyConfirmation) {
            Button(L10n.Beta.acknowledgeAndReveal) {
                session.hasAcknowledgedRevealSafety = true
                isBetaRevealed = true
            }
            .accessibilityIdentifier("acknowledge-beta-safety-button")
            Button(L10n.Common.cancel, role: .cancel) {}
        } message: {
            Text(L10n.Beta.safetyMessage)
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
    }

    private var archivedBanner: some View {
        Label(L10n.Route.archivedHistoryMessage, systemImage: "archivebox")
            .font(.subheadline)
            .foregroundStyle(DesignColour.warning)
            .cardStyle()
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
                .fill(.regularMaterial)
                .frame(height: 180)
                .overlay {
                    VStack {
                        Image(systemName: "circle.hexagongrid.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(DesignColour.opticBlue)
                        Text(L10n.Route.photoPlaceholder)
                            .font(.caption)
                            .foregroundStyle(DesignColour.secondaryText)
                    }
                }

            HStack(alignment: .firstTextBaseline) {
                Text(route.colourOrTag).font(.title.bold())
                Spacer()
                Text(route.officialGrade?.displayName ?? String(localized: L10n.Grade.unknown))
                    .font(.title2.bold())
            }
            if let archiveDate = route.expectedArchiveDate, route.isArchiveDateEstimated {
                Label {
                    Text(L10n.Route.estimatedArchive) + Text(verbatim: " \(archiveDate.formatted(date: .abbreviated, time: .omitted))")
                } icon: {
                    Image(systemName: "calendar.badge.exclamationmark")
                }
                .font(.caption)
                .foregroundStyle(DesignColour.warning)
            }
        }
    }

    private var quickLogbookSection: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.medium) {
            Text(L10n.Logbook.quickStateTitle).font(.title3.bold())
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DesignSpacing.small) {
                ForEach(LogbookStatus.allCases, id: \.self) { status in
                    Button {
                        Task {
                            if await viewModel.save(status: status) != nil {
                                showsLogbookDetails = true
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: viewModel.logbookEntry?.status == status ? "checkmark.circle.fill" : "circle")
                            Text(L10n.logbookStatus(status))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(viewModel.logbookEntry?.status == status ? DesignColour.opticBlue : DesignColour.secondaryText)
                    .accessibilityIdentifier("logbook-status-\(status.rawValue)")
                }
            }
            if let entry = viewModel.logbookEntry {
                Label(
                    entry.syncState == .queued ? L10n.Logbook.queued : L10n.Logbook.savedPrivate,
                    systemImage: entry.syncState == .queued ? "clock.arrow.circlepath" : "lock.fill"
                )
                .font(.caption)
                .foregroundStyle(entry.syncState == .queued ? DesignColour.warning : DesignColour.success)
            }
        }
        .cardStyle()
    }

    private var betaSection: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.medium) {
            Text(L10n.Beta.title).font(.title3.bold())
            if !isBetaRevealed {
                ZStack {
                    LinearGradient(
                        colors: [DesignColour.opticBlue, DesignColour.surface, DesignColour.warning],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .blur(radius: 14)
                    Text(L10n.Beta.hiddenUntilReveal)
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: DesignRadius.medium))

                Button(L10n.Beta.reveal) {
                    if session.hasAcknowledgedRevealSafety {
                        isBetaRevealed = true
                    } else {
                        showsSafetyConfirmation = true
                    }
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("reveal-beta-button")
            } else {
                revealedBetaContent
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
                BetaLinkCard(link: link)
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
}

private struct BetaLinkCard: View {
    let link: BetaLink

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.small) {
            betaMetadataRow(
                L10n.Beta.platform,
                value: String(localized: L10n.betaPlatform(link.platform))
            )
            betaMetadataRow(L10n.Beta.originalAuthor, value: link.originalAuthor)
            FlowLayout(tags: link.tags)
            Label {
                Text(link.helpfulCount, format: .number) + Text(L10n.Beta.helpfulSuffix)
            } icon: {
                Image(systemName: "hand.thumbsup")
            }
                .font(.caption)

            if link.embedSupport == .supported {
                Text(L10n.Beta.inlineFutureMessage)
                    .font(.caption)
                    .foregroundStyle(DesignColour.secondaryText)
            } else {
                Link(destination: link.sourceURL) {
                    Label(L10n.Beta.openSource, systemImage: "arrow.up.right.square")
                }
            }
            Link(L10n.Beta.originalPost, destination: link.originalPostURL)
                .font(.caption)
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
