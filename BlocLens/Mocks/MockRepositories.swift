import Foundation

actor MockGymRepository: GymRepository {
    private let gyms: [Gym]
    private let zones: [WallZone]
    private let scenario: MockRepositoryScenario

    init(
        gyms: [Gym] = DevelopmentFixtures.gyms,
        zones: [WallZone] = DevelopmentFixtures.wallZones,
        scenario: MockRepositoryScenario = .loaded
    ) {
        self.gyms = gyms
        self.zones = zones
        self.scenario = scenario
    }

    func allGyms() throws -> [Gym] {
        try resolved(gyms)
    }

    func gym(id: GymID) throws -> Gym {
        try throwForUnavailableScenario()
        guard let gym = gyms.first(where: { $0.id == id }) else { throw RepositoryError.notFound }
        return gym
    }

    func searchGyms(query: String) throws -> [Gym] {
        let available = try resolved(gyms)
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return available }
        return available.filter {
            $0.name.localizedCaseInsensitiveContains(term)
                || $0.brandName.localizedCaseInsensitiveContains(term)
                || $0.suburb.localizedCaseInsensitiveContains(term)
        }
    }

    func wallZones(gymID: GymID) throws -> [WallZone] {
        try resolved(zones.filter { $0.gymID == gymID }.sorted { $0.sortOrder < $1.sortOrder })
    }

    func allWallZones() throws -> [WallZone] {
        try resolved(zones)
    }

    private func resolved<Value>(_ values: [Value]) throws -> [Value] {
        switch scenario {
        case .loaded, .offlineWithCache: values
        case .empty: []
        case .error: throw RepositoryError.fixtureFailure
        case .offlineWithoutCache: throw RepositoryError.offlineNoCache
        }
    }

    private func throwForUnavailableScenario() throws {
        switch scenario {
        case .loaded, .offlineWithCache: return
        case .empty: throw RepositoryError.notFound
        case .error: throw RepositoryError.fixtureFailure
        case .offlineWithoutCache: throw RepositoryError.offlineNoCache
        }
    }
}

actor MockRouteRepository: RouteRepository {
    private let routeFixtures: [ClimbingRoute]
    private let scenario: MockRepositoryScenario

    init(
        routes: [ClimbingRoute] = DevelopmentFixtures.routes,
        scenario: MockRepositoryScenario = .loaded
    ) {
        routeFixtures = routes
        self.scenario = scenario
    }

    func routes(wallZoneID: WallZoneID, filter: RouteFilter) throws -> [ClimbingRoute] {
        let zoneRoutes = try resolved(routeFixtures.filter { $0.wallZoneID == wallZoneID })
        return apply(filter: filter, to: zoneRoutes)
    }

    func route(id: ClimbingRouteID) throws -> ClimbingRoute {
        try throwForUnavailableScenario()
        guard let route = routeFixtures.first(where: { $0.id == id }) else {
            throw RepositoryError.notFound
        }
        return route
    }

    func searchRoutes(query: String, includesArchived: Bool) throws -> [ClimbingRoute] {
        let filter = RouteFilter(query: query, gradeBand: .all, includesArchived: includesArchived)
        return apply(filter: filter, to: try resolved(routeFixtures))
    }

    func suspectedDuplicates(for query: DuplicateRouteQuery) throws -> [ClimbingRoute] {
        try resolved(routeFixtures.filter {
            $0.gymID == query.gymID
                && $0.wallZoneID == query.wallZoneID
                && $0.colourOrTag.localizedCaseInsensitiveCompare(query.colourOrTag) == .orderedSame
        })
    }

    func allRoutes() throws -> [ClimbingRoute] {
        try resolved(routeFixtures)
    }

    private func apply(filter: RouteFilter, to routes: [ClimbingRoute]) -> [ClimbingRoute] {
        routes.filter { route in
            let matchesLifecycle = filter.includesArchived || route.lifecycle == .active
            let matchesGrade = filter.gradeBand.contains(route.officialGrade)
            let term = filter.query.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesQuery = term.isEmpty
                || route.colourOrTag.localizedCaseInsensitiveContains(term)
                || route.officialGrade?.displayName.localizedCaseInsensitiveContains(term) == true
                || route.communityGradeSummary.displayGrade?.displayName.localizedCaseInsensitiveContains(term) == true
            return matchesLifecycle && matchesGrade && matchesQuery
        }
        .sorted { lhs, rhs in
            if lhs.lifecycle != rhs.lifecycle { return lhs.lifecycle == .active }
            let lhsGrade = lhs.officialGrade ?? .unknown
            let rhsGrade = rhs.officialGrade ?? .unknown
            if lhsGrade != rhsGrade { return lhsGrade < rhsGrade }
            return lhs.id.rawValue < rhs.id.rawValue
        }
    }

    private func resolved<Value>(_ values: [Value]) throws -> [Value] {
        switch scenario {
        case .loaded, .offlineWithCache: values
        case .empty: []
        case .error: throw RepositoryError.fixtureFailure
        case .offlineWithoutCache: throw RepositoryError.offlineNoCache
        }
    }

    private func throwForUnavailableScenario() throws {
        switch scenario {
        case .loaded, .offlineWithCache: return
        case .empty: throw RepositoryError.notFound
        case .error: throw RepositoryError.fixtureFailure
        case .offlineWithoutCache: throw RepositoryError.offlineNoCache
        }
    }
}

actor MockBetaRepository: BetaRepository {
    private let links: [BetaLink]
    private let scenario: MockRepositoryScenario

    init(
        links: [BetaLink] = DevelopmentFixtures.betaLinks,
        scenario: MockRepositoryScenario = .loaded
    ) {
        self.links = links.filter {
            BetaLink.isValidExternalURL($0.sourceURL)
                && BetaLink.isValidExternalURL($0.originalPostURL)
        }
        self.scenario = scenario
    }

    func betaLinks(routeID: ClimbingRouteID, viewer: BetaViewerProfile?) throws -> [BetaLink] {
        let routeLinks = try resolved(links.filter { $0.routeID == routeID })
        return BetaRanker.visibleLinks(routeLinks, viewer: viewer)
    }

    func brokenBetaLinks(routeID: ClimbingRouteID) throws -> [BetaLink] {
        try resolved(links.filter {
            $0.routeID == routeID
                && $0.linkHealth == .broken
                && $0.moderationState == .visible
        })
    }

    func validateExternalURL(_ url: URL) -> Bool {
        BetaLink.isValidExternalURL(url)
    }

    private func resolved<Value>(_ values: [Value]) throws -> [Value] {
        switch scenario {
        case .loaded, .offlineWithCache: values
        case .empty: []
        case .error: throw RepositoryError.fixtureFailure
        case .offlineWithoutCache: throw RepositoryError.offlineNoCache
        }
    }
}

actor MockLogbookRepository: LogbookRepository {
    private var storedEntries: [LogbookEntry]
    private var online: Bool

    init(entries: [LogbookEntry] = DevelopmentFixtures.logbookEntries, isOnline: Bool = true) {
        storedEntries = entries
        online = isOnline
    }

    func entries(userID: UserID) -> [LogbookEntry] {
        storedEntries.filter { $0.userID == userID }.sorted { $0.date > $1.date }
    }

    func entry(userID: UserID, routeID: ClimbingRouteID) -> LogbookEntry? {
        storedEntries.first { $0.userID == userID && $0.routeID == routeID }
    }

    func saveStatus(
        userID: UserID,
        routeID: ClimbingRouteID,
        status: LogbookStatus,
        date: Date
    ) -> LogbookEntry {
        if let index = storedEntries.firstIndex(where: { $0.userID == userID && $0.routeID == routeID }) {
            storedEntries[index].status = status
            storedEntries[index].date = date
            storedEntries[index].syncState = online ? .synced : .queued
            return storedEntries[index]
        }

        let newEntry = LogbookEntry(
            id: LogbookEntryID(rawValue: "session-\(userID.rawValue)-\(routeID.rawValue)"),
            userID: userID,
            routeID: routeID,
            status: status,
            date: date,
            attemptCount: nil,
            privateNote: nil,
            predictedVGrade: nil,
            syncState: online ? .synced : .queued,
            privacy: .privateByDefault
        )
        storedEntries.append(newEntry)
        return newEntry
    }

    func updateDetails(entryID: LogbookEntryID, details: LogbookDetails) throws -> LogbookEntry {
        guard let index = storedEntries.firstIndex(where: { $0.id == entryID }) else {
            throw RepositoryError.notFound
        }
        storedEntries[index].date = details.date
        storedEntries[index].attemptCount = details.attemptCount
        storedEntries[index].privateNote = details.privateNote
        storedEntries[index].predictedVGrade = details.predictedVGrade
        storedEntries[index].syncState = online ? .synced : .queued
        return storedEntries[index]
    }

    func projects(userID: UserID) -> [LogbookEntry] {
        storedEntries.filter { $0.userID == userID && $0.status == .projecting }.sorted { $0.date > $1.date }
    }

    func setOnline(_ isOnline: Bool) {
        online = isOnline
    }

    func isOnline() -> Bool {
        online
    }

    func synchroniseQueuedEntries() -> [LogbookEntry] {
        guard online else { return storedEntries.filter { $0.syncState == .queued } }
        for index in storedEntries.indices where storedEntries[index].syncState == .queued {
            storedEntries[index].syncState = .synced
        }
        return storedEntries.filter { $0.syncState == .synced }
    }
}
