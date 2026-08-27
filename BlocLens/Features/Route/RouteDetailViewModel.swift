import Combine
import Foundation

@MainActor
final class RouteDetailViewModel: ObservableObject {
    @Published private(set) var betaState: LoadableState<[BetaLink]> = .initial
    @Published private(set) var brokenLinks: [BetaLink] = []
    @Published private(set) var logbookEntry: LogbookEntry?
    @Published private(set) var wallZone: WallZone?
    @Published private(set) var comments: [BetaComment] = []
    @Published private(set) var contributionMessage: String?
    @Published private(set) var saveError: RepositoryError?

    private let route: ClimbingRoute
    private let betaRepository: any BetaRepository
    private let logbookRepository: any LogbookRepository
    private let userIDProvider: @Sendable () -> UserID?
    private let gymRepository: any GymRepository
    private let contributionRepository: any ContributionRepository

    init(route: ClimbingRoute, environment: AppEnvironment) {
        self.route = route
        betaRepository = environment.betaRepository
        logbookRepository = environment.logbookRepository
        gymRepository = environment.gymRepository
        contributionRepository = environment.contributionRepository
        userIDProvider = environment.currentUserID
    }

    func load(viewerProfile: UserProfile? = nil) async {
        betaState = .loading
        do {
            async let betaRequest = betaRepository.betaLinks(
                routeID: route.id,
                viewer: viewerProfile.map {
                    BetaViewerProfile(
                        heightCentimetres: $0.heightCentimetres,
                        armSpanCentimetres: $0.armSpanCentimetres
                    )
                }
            )
            async let brokenRequest = betaRepository.brokenBetaLinks(routeID: route.id)
            async let entryRequest = currentUserEntry()
            async let zonesRequest = gymRepository.allWallZones()
            let (links, broken, entry, zones) = try await (betaRequest, brokenRequest, entryRequest, zonesRequest)
            betaState = links.isEmpty ? .empty : .loaded(links)
            brokenLinks = broken
            logbookEntry = entry
            wallZone = zones.first { $0.id == route.wallZoneID }
            if let betaID = links.first?.id {
                comments = try await contributionRepository.comments(betaLinkID: betaID)
            } else {
                comments = []
            }
        } catch RepositoryError.offlineNoCache {
            betaState = .offlineWithoutCache
        } catch let error as RepositoryError {
            betaState = .error(error)
        } catch {
            betaState = .error(.fixtureFailure)
        }
    }

    @discardableResult
    func save(status: LogbookStatus) async -> LogbookEntry? {
        do {
            guard let userID = userIDProvider() else { throw RepositoryError.unauthenticated }
            let entry = try await logbookRepository.saveStatus(
                userID: userID,
                routeID: route.id,
                status: status,
                date: Date()
            )
            logbookEntry = entry
            saveError = nil
            return entry
        } catch let error as RepositoryError {
            saveError = error
            return nil
        } catch {
            saveError = .fixtureFailure
            return nil
        }
    }

    private func currentUserEntry() async throws -> LogbookEntry? {
        guard let userID = userIDProvider() else { return nil }
        return try await logbookRepository.entry(userID: userID, routeID: route.id)
    }

    @discardableResult
    func update(details: LogbookDetails) async -> LogbookEntry? {
        guard let entry = logbookEntry else { return nil }
        do {
            let updated = try await logbookRepository.updateDetails(entryID: entry.id, details: details)
            logbookEntry = updated
            saveError = nil
            return updated
        } catch let error as RepositoryError {
            saveError = error
            return nil
        } catch {
            saveError = .fixtureFailure
            return nil
        }
    }

    func clearSaveError() {
        saveError = nil
    }

    @discardableResult
    func addPhoto(url: URL) async -> Bool {
        await contributionResult {
            _ = try await self.contributionRepository.addRoutePhoto(
                AddRoutePhotoRequest(
                    idempotencyKey: IdempotencyKey(), routeID: self.route.id,
                    publicImageURL: url, width: nil, height: nil
                )
            )
            return "Photo metadata saved. Credit is linked to your account."
        }
    }

    @discardableResult
    func submitCorrection(
        issue: RouteCorrectionIssue,
        proposedValue: String,
        explanation: String
    ) async -> Bool {
        await contributionResult {
            _ = try await self.contributionRepository.submitCorrection(
                SubmitRouteCorrectionRequest(
                    idempotencyKey: IdempotencyKey(), routeID: self.route.id, issue: issue,
                    proposedValue: proposedValue, explanation: explanation
                )
            )
            return "Correction submitted for review."
        }
    }

    @discardableResult
    func confirmReset() async -> Bool {
        await contributionResult {
            let receipt = try await self.contributionRepository.confirmReset(
                ConfirmResetRequest(
                    idempotencyKey: IdempotencyKey(), gymID: self.route.gymID,
                    wallZoneID: self.route.wallZoneID, resetDate: Date()
                )
            )
            return receipt.isOfficial || receipt.state == .confirmed
                ? "Reset confirmed."
                : "Reset confirmation recorded. Three different climbers are required."
        }
    }

    @discardableResult
    func addComment(betaID: BetaLinkID, body: String, officialGymID: GymID?) async -> Bool {
        await contributionResult {
            let comment = try await self.contributionRepository.addComment(
                AddBetaCommentRequest(
                    idempotencyKey: IdempotencyKey(), betaLinkID: betaID,
                    body: body, officialGymID: officialGymID
                )
            )
            self.comments.append(comment)
            return "Comment published."
        }
    }

    @discardableResult
    func report(
        targetType: ReportableContentType,
        targetID: String,
        category: ContentReportCategory,
        details: String
    ) async -> Bool {
        await contributionResult {
            _ = try await self.contributionRepository.reportContent(
                SubmitContentReportRequest(
                    idempotencyKey: IdempotencyKey(), targetType: targetType,
                    targetID: targetID, category: category, details: details
                )
            )
            return category.isSevere
                ? "Report submitted for priority review."
                : "Report submitted. Repeated reports from the same account do not increase the threshold."
        }
    }

    @discardableResult
    func markHelpful(betaID: BetaLinkID) async -> Bool {
        do {
            try await betaRepository.markHelpful(betaID)
            contributionMessage = "Marked as helpful."
            saveError = nil
            return true
        } catch let error as RepositoryError {
            saveError = error
            return false
        } catch {
            saveError = .unknown
            return false
        }
    }

    func clearContributionMessage() {
        contributionMessage = nil
    }

    private func contributionResult(_ operation: () async throws -> String) async -> Bool {
        do {
            contributionMessage = try await operation()
            saveError = nil
            return true
        } catch let error as RepositoryError {
            saveError = error
            return false
        } catch {
            saveError = .unknown
            return false
        }
    }
}
