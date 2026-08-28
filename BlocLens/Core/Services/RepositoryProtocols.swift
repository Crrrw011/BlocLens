import Foundation

nonisolated enum RepositoryError: Error, Equatable, Sendable {
    case notFound
    case invalidExternalLink
    case fixtureFailure
    case offlineNoCache

    case unavailable
    case offline
    case unauthenticated
    case forbidden
    case network
    case timeout
    case rateLimited
    case decodingFailure
    case invalidConfiguration
    case invalidInput
    case invalidState
    case conflict
    case persistenceError
    case userCancelled
    case externalServiceError
    case unknown
}

nonisolated enum MockRepositoryScenario: Equatable, Sendable {
    case loaded
    case empty
    case error
    case offlineWithCache
    case offlineWithoutCache
}

nonisolated enum DataAvailability: Equatable, Sendable {
    case online
    case offlineCached
}

nonisolated struct RouteFilter: Equatable, Hashable, Sendable {
    var query: String = ""
    var gradeBand: GradeBand = .all
    var includesArchived = false
}

nonisolated struct DuplicateRouteQuery: Equatable, Hashable, Sendable {
    let gymID: GymID
    let wallZoneID: WallZoneID
    let colour: String
    let resetDate: Date?
}

nonisolated protocol GymRepository: Sendable {
    func allGyms() async throws -> [Gym]
    func gym(id: GymID) async throws -> Gym
    func searchGyms(query: String) async throws -> [Gym]
    func wallZones(gymID: GymID) async throws -> [WallZone]
    func allWallZones() async throws -> [WallZone]
}

nonisolated protocol RouteRepository: Sendable {
    func routes(wallZoneID: WallZoneID, filter: RouteFilter) async throws -> [ClimbingRoute]
    func route(id: ClimbingRouteID) async throws -> ClimbingRoute
    func searchRoutes(query: String, includesArchived: Bool) async throws -> [ClimbingRoute]
    func suspectedDuplicates(for query: DuplicateRouteQuery) async throws -> [ClimbingRoute]
    func allRoutes() async throws -> [ClimbingRoute]
}

nonisolated protocol BetaRepository: Sendable {
    func betaLinks(routeID: ClimbingRouteID, viewer: BetaViewerProfile?) async throws -> [BetaLink]
    func brokenBetaLinks(routeID: ClimbingRouteID) async throws -> [BetaLink]
    func validateExternalURL(_ url: URL) async -> Bool

    func betaMetadata(for routeID: ClimbingRouteID) async throws -> [BetaLink]
    func revealBeta(_ betaID: BetaLinkID) async throws -> BetaLink
    func markHelpful(_ betaID: BetaLinkID) async throws
    func reportBeta(_ betaID: BetaLinkID, reason: ReportReason) async throws
    func communityGradeVote(routeID: ClimbingRouteID, grade: VGrade) async throws
    func myGradeVote(for routeID: ClimbingRouteID) async throws -> VGrade?
    func hasConfirmedSafety() async -> Bool
    func confirmSafety() async throws
}

nonisolated protocol LogbookRepository: Sendable {
    func entries(userID: UserID) async throws -> [LogbookEntry]
    func entry(userID: UserID, routeID: ClimbingRouteID) async throws -> LogbookEntry?
    func saveStatus(
        userID: UserID,
        routeID: ClimbingRouteID,
        status: LogbookStatus,
        date: Date
    ) async throws -> LogbookEntry
    func updateDetails(entryID: LogbookEntryID, details: LogbookDetails) async throws -> LogbookEntry
    func projects(userID: UserID) async throws -> [LogbookEntry]
    func setOnline(_ isOnline: Bool) async
    func isOnline() async -> Bool
    func synchroniseQueuedEntries() async throws -> [LogbookEntry]

    func hasAttemptedRoute(_ routeID: ClimbingRouteID) async throws -> Bool
    func saveEntry(_ entry: LogbookEntry) async throws -> LogbookEntry
    func deleteEntry(_ entryID: LogbookEntryID) async throws
    func pendingSyncCount() async -> Int
    func syncNow() async throws
}

nonisolated protocol ContributionRepository: Sendable {
    func addRoute(_ request: AddRouteRequest) async throws -> ClimbingRoute
    func createWallZone(_ request: AddWallZoneRequest) async throws -> WallZone
    func updateWallZone(_ wallZoneID: WallZoneID, request: AddWallZoneRequest) async throws -> WallZone
    func shareBetaLink(_ request: ShareBetaLinkRequest) async throws -> BetaLink
    func addRoutePhoto(_ request: AddRoutePhotoRequest) async throws -> RoutePhotoMetadata
    func submitCorrection(_ request: SubmitRouteCorrectionRequest) async throws -> RouteCorrectionReceipt
    func confirmReset(_ request: ConfirmResetRequest) async throws -> ResetConfirmationReceipt
    func comments(betaLinkID: BetaLinkID) async throws -> [BetaComment]
    func addComment(_ request: AddBetaCommentRequest) async throws -> BetaComment
    func reportContent(_ request: SubmitContentReportRequest) async throws -> ContentReportReceipt
}

nonisolated protocol RelationshipRepository: Sendable {
    func publicProfiles() async throws -> [PublicUserProfile]
    func blockedProfiles() async throws -> [PublicUserProfile]
    func state(with userID: UserID) async throws -> UserRelationshipState
    func follow(userID: UserID, idempotencyKey: IdempotencyKey) async throws
    func unfollow(userID: UserID, idempotencyKey: IdempotencyKey) async throws
    func block(userID: UserID, idempotencyKey: IdempotencyKey) async throws
    func unblock(userID: UserID, idempotencyKey: IdempotencyKey) async throws
}

nonisolated protocol RoleRepository: Sendable {
    func sessionRoleContext() async throws -> SessionRoleContext
}
