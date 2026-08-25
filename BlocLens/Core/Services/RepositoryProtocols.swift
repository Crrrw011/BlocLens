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
    let colourOrTag: String
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
}
