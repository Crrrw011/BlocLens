import Foundation
import Supabase
import Testing
@testable import BlocLens

@MainActor
struct RemoteRepositoryTests {
    private func makeUUID(_ suffix: Int) throws -> UUID {
        try #require(UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", suffix)))
    }

    // MARK: - Configuration

    @Test func productionAcceptsHTTPS() throws {
        let url = try #require(URL(string: "https://example.com"))
        let config = try RemoteConfiguration(mode: .production, projectURL: url, publishableKey: "key")
        #expect(config.mode == .production)
    }

    @Test func productionAcceptsSupabaseCloudHTTPS() throws {
        let url = try #require(URL(string: "https://project-ref.supabase.co"))
        let config = try RemoteConfiguration(mode: .production, projectURL: url, publishableKey: "key")
        #expect(config.projectURL.host == "project-ref.supabase.co")
    }

    @Test func productionRejectsHTTP() throws {
        let url = try #require(URL(string: "http://example.com"))
        #expect(throws: RepositoryError.self) {
            try RemoteConfiguration(mode: .production, projectURL: url, publishableKey: "key")
        }
    }

    @Test func localAcceptsLoopbackHTTP() throws {
        let url = try #require(URL(string: "http://127.0.0.1:54321"))
        let config = try RemoteConfiguration(mode: .localDevelopment, projectURL: url, publishableKey: "key")
        #expect(config.projectURL.host == "127.0.0.1")
    }

    @Test func localRejectsNonLoopbackHTTP() throws {
        let url = try #require(URL(string: "http://192.168.1.5:54321"))
        #expect(throws: RepositoryError.self) {
            try RemoteConfiguration(mode: .localDevelopment, projectURL: url, publishableKey: "key")
        }
    }

    @Test func rejectsEmptyKey() throws {
        let url = try #require(URL(string: "https://example.com"))
        #expect(throws: RepositoryError.self) {
            try RemoteConfiguration(mode: .production, projectURL: url, publishableKey: "   ")
        }
    }

    @Test func localRejectsCloudHost() throws {
        let url = try #require(URL(string: "https://abc.supabase.co"))
        #expect(throws: RepositoryError.self) {
            try RemoteConfiguration(mode: .localDevelopment, projectURL: url, publishableKey: "key")
        }
    }

    @Test func missingEnvironmentConfigurationReturnsNil() throws {
        #expect(try LocalEnvironmentConfiguration.make(environment: [:]) == nil)
    }

    // MARK: - Error mapping

    @Test func errorMappingDistinguishesSDKErrors() throws {
        #expect(RemoteErrorMapping.map(URLError(.timedOut)) == .timeout)
        #expect(RemoteErrorMapping.map(URLError(.notConnectedToInternet)) == .network)

        #expect(RemoteErrorMapping.map(PostgrestError(code: "PGRST116", message: "m")) == .notFound)
        #expect(RemoteErrorMapping.map(PostgrestError(code: "42501", message: "m")) == .forbidden)

        let url = try #require(URL(string: "https://example.com"))
        let unauthorized = try #require(HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: nil))
        #expect(RemoteErrorMapping.map(HTTPError(data: Data(), response: unauthorized)) == .unauthenticated)

        let forbidden = try #require(HTTPURLResponse(url: url, statusCode: 403, httpVersion: nil, headerFields: nil))
        #expect(RemoteErrorMapping.map(HTTPError(data: Data(), response: forbidden)) == .forbidden)

        let rateLimited = try #require(HTTPURLResponse(url: url, statusCode: 429, httpVersion: nil, headerFields: nil))
        #expect(RemoteErrorMapping.map(HTTPError(data: Data(), response: rateLimited)) == .rateLimited)

        let decodeError = DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "x"))
        #expect(RemoteErrorMapping.map(decodeError) == .decodingFailure)
    }

    // MARK: - Gym aggregation

    @Test func remoteGymRepositoryAggregatesSources() async throws {
        let gymID = try makeUUID(1)
        let zoneID = try makeUUID(2)
        let record = GymRecord(
            id: gymID, name: "Test Gym", brandName: "Brand", latitude: -27.0, longitude: 153.0,
            suburb: "West End", state: "QLD", isVerified: true, dataSource: "official",
            betaCount: 2, latestResetDate: nil
        )
        let facility = GymFacilityRecord(gymID: gymID, facility: "showers", isAvailable: true)
        let zone = WallZoneRecord(
            id: zoneID, gymID: gymID, name: "Main Wall", locationDescription: "Central",
            wallKind: "regular_set_wall", surfaceMaterial: "plywood", surfaceTexture: "lightly_textured",
            hasBoltHoles: true, createdBy: nil, displayOrder: 0, availability: "active", lastResetDate: nil,
            currentRouteCount: 3, betaCount: 2
        )
        let band = GymHardSoftBandRecord(gradeBand: "Overall", eligibleRouteCount: 3, medianGradeDelta: 0.5, assessment: "hard")
        let dataSource = FakeGymDataSource(gyms: [record], facilities: [facility], zones: [zone], hardSoft: [gymID: [band]])

        let gyms = try await RemoteGymRepository(dataSource: dataSource).allGyms()

        #expect(gyms.count == 1)
        #expect(gyms[0].overallHardSoftSummary == .hard)
        #expect(gyms[0].facilities == [.showers])
        #expect(gyms[0].wallZoneIDs == [WallZoneID(rawValue: zoneID.uuidString.lowercased())])
    }

    @Test func gymInsufficientDataMapsWithoutFabricating() async throws {
        let gymID = try makeUUID(1)
        let record = GymRecord(
            id: gymID, name: "Sparse Gym", brandName: nil, latitude: -27.0, longitude: 153.0,
            suburb: "Enoggera", state: "QLD", isVerified: false, dataSource: "community",
            betaCount: 0, latestResetDate: nil
        )
        let band = GymHardSoftBandRecord(gradeBand: "Overall", eligibleRouteCount: 0, medianGradeDelta: nil, assessment: "not_enough_community_data")
        let dataSource = FakeGymDataSource(gyms: [record], facilities: [], zones: [], hardSoft: [gymID: [band]])

        let gyms = try await RemoteGymRepository(dataSource: dataSource).allGyms()

        #expect(gyms[0].overallHardSoftSummary == .insufficientData)
    }

    @Test func gymNotFoundMapsToNotFound() async throws {
        let dataSource = FakeGymDataSource(gyms: [], facilities: [], zones: [], hardSoft: [:])
        let repository = RemoteGymRepository(dataSource: dataSource)
        do {
            _ = try await repository.gym(id: GymID(rawValue: try makeUUID(99).uuidString.lowercased()))
            Issue.record("Expected notFound")
        } catch let error as RepositoryError {
            #expect(error == .notFound)
        }
    }

    @Test func gymSearchMatchesNameAndSuburb() async throws {
        let gymID = try makeUUID(1)
        let record = GymRecord(
            id: gymID, name: "Urban Climb West End", brandName: "Urban Climb", latitude: -27.0,
            longitude: 153.0, suburb: "West End", state: "QLD", isVerified: true,
            dataSource: "official", betaCount: 0, latestResetDate: nil
        )
        let band = GymHardSoftBandRecord(gradeBand: "Overall", eligibleRouteCount: 0, medianGradeDelta: nil, assessment: "not_enough_community_data")
        let dataSource = FakeGymDataSource(gyms: [record], facilities: [], zones: [], hardSoft: [gymID: [band]])
        let repository = RemoteGymRepository(dataSource: dataSource)

        let matches = try await repository.searchGyms(query: "west end")
        #expect(matches.count == 1)
    }

    // MARK: - Route mapping

    @Test func routeMapsCurrentWithCommunityGrade() async throws {
        let gymID = try makeUUID(1)
        let zoneID = try makeUUID(2)
        let routeID = try makeUUID(3)
        let record = RouteRecord(
            id: routeID, gymID: gymID, wallZoneID: zoneID, colour: "Blue", terrain: "slab", styles: [], subjectiveGrade: nil,
            gymGrade: 2, lifecycle: "active", setDate: nil, estimatedArchiveDate: nil,
            isArchiveDateEstimated: false, archivedAt: nil, betaCount: 4, createdBy: nil
        )
        let grade = CommunityGradeRecord(routeID: routeID, voteCount: 3, isDisplayEligible: true, medianVGrade: 3)
        let dataSource = FakeRouteDataSource(routes: [record], grades: [routeID: grade])

        let routes = try await RemoteRouteRepository(dataSource: dataSource).allRoutes()

        #expect(routes.count == 1)
        #expect(routes[0].lifecycle == .active)
        #expect(routes[0].communityGradeSummary.displayGrade == .v3)
    }

    @Test func routeHidesCommunityGradeBelowThreeVotes() async throws {
        let gymID = try makeUUID(1)
        let zoneID = try makeUUID(2)
        let routeID = try makeUUID(3)
        let record = RouteRecord(
            id: routeID, gymID: gymID, wallZoneID: zoneID, colour: "Red", terrain: "slab", styles: [], subjectiveGrade: nil,
            gymGrade: 0, lifecycle: "active", setDate: nil, estimatedArchiveDate: nil,
            isArchiveDateEstimated: false, archivedAt: nil, betaCount: 0, createdBy: nil
        )
        let grade = CommunityGradeRecord(routeID: routeID, voteCount: 2, isDisplayEligible: false, medianVGrade: nil)
        let dataSource = FakeRouteDataSource(routes: [record], grades: [routeID: grade])

        let routes = try await RemoteRouteRepository(dataSource: dataSource).allRoutes()

        #expect(routes[0].communityGradeSummary.displayGrade == nil)
        #expect(routes[0].communityGradeSummary.voteCount == 2)
    }

    @Test func routeArchivedMapsDistinctly() async throws {
        let gymID = try makeUUID(1)
        let zoneID = try makeUUID(2)
        let routeID = try makeUUID(3)
        let record = RouteRecord(
            id: routeID, gymID: gymID, wallZoneID: zoneID, colour: "Orange", terrain: "slab", styles: [], subjectiveGrade: nil,
            gymGrade: 8, lifecycle: "archived", setDate: nil, estimatedArchiveDate: nil,
            isArchiveDateEstimated: false, archivedAt: Date(), betaCount: 1, createdBy: nil
        )
        let grade = CommunityGradeRecord(routeID: routeID, voteCount: 0, isDisplayEligible: false, medianVGrade: nil)
        let dataSource = FakeRouteDataSource(routes: [record], grades: [routeID: grade])

        let routes = try await RemoteRouteRepository(dataSource: dataSource).allRoutes()

        #expect(routes[0].lifecycle == .archived)
    }

    @Test func routeNotFoundMapsToNotFound() async throws {
        let dataSource = FakeRouteDataSource(routes: [], grades: [:])
        let repository = RemoteRouteRepository(dataSource: dataSource)
        do {
            _ = try await repository.route(id: ClimbingRouteID(rawValue: try makeUUID(99).uuidString.lowercased()))
            Issue.record("Expected notFound")
        } catch let error as RepositoryError {
            #expect(error == .notFound)
        }
    }

    @Test func suspectedDuplicatesReturnsMatches() async throws {
        let gymID = try makeUUID(1)
        let zoneID = try makeUUID(2)
        let routeID = try makeUUID(3)
        let record = RouteRecord(
            id: routeID, gymID: gymID, wallZoneID: zoneID, colour: "Blue", terrain: "slab", styles: [], subjectiveGrade: nil,
            gymGrade: 2, lifecycle: "active", setDate: nil, estimatedArchiveDate: nil,
            isArchiveDateEstimated: false, archivedAt: nil, betaCount: 0, createdBy: nil
        )
        let dataSource = FakeRouteDataSource(routes: [record], grades: [:])

        let duplicates = try await RemoteRouteRepository(dataSource: dataSource).suspectedDuplicates(
            for: DuplicateRouteQuery(
                gymID: GymID(rawValue: gymID.uuidString.lowercased()),
                wallZoneID: WallZoneID(rawValue: zoneID.uuidString.lowercased()),
                colour: "Blue",
                resetDate: nil
            )
        )
        #expect(duplicates.count == 1)
    }

    @Test func mockEnvironmentRemainsDefault() async throws {
        let environment = AppEnvironment.development()
        #expect(environment.gymRepository is MockGymRepository)
        #expect(environment.routeRepository is MockRouteRepository)
    }

    @Test func localSupabaseWiresRemoteRepositories() throws {
        let url = try #require(URL(string: "http://127.0.0.1:54321"))
        let config = try RemoteConfiguration(mode: .localDevelopment, projectURL: url, publishableKey: "key")
        let environment = AppEnvironment.localSupabase(configuration: config)
        #expect(environment.gymRepository is RemoteGymRepository)
        #expect(environment.routeRepository is RemoteRouteRepository)
    }
}

// MARK: - Fake data sources (in-memory, no network)

private struct FakeGymDataSource: RemoteGymDataSource, Sendable {
    var gyms: [GymRecord]
    var facilities: [GymFacilityRecord]
    var zones: [WallZoneRecord]
    var hardSoft: [UUID: [GymHardSoftBandRecord]]
    var error: RepositoryError?

    func fetchGymSummaries() async throws -> [GymRecord] {
        if let error { throw error }
        return gyms
    }

    func fetchGymSummary(id: UUID) async throws -> GymRecord {
        if let error { throw error }
        guard let gym = gyms.first(where: { $0.id == id }) else { throw RepositoryError.notFound }
        return gym
    }

    func fetchFacilities() async throws -> [GymFacilityRecord] {
        if let error { throw error }
        return facilities
    }

    func fetchWallZoneSummaries() async throws -> [WallZoneRecord] {
        if let error { throw error }
        return zones
    }

    func fetchHardSoftBands(gymID: UUID) async throws -> [GymHardSoftBandRecord] {
        if let error { throw error }
        return hardSoft[gymID] ?? []
    }
}

private struct FakeRouteDataSource: RemoteRouteDataSource, Sendable {
    var routes: [RouteRecord]
    var grades: [UUID: CommunityGradeRecord]
    var error: RepositoryError?

    func fetchRouteSummaries() async throws -> [RouteRecord] {
        if let error { throw error }
        return routes
    }

    func fetchRouteSummary(id: UUID) async throws -> RouteRecord {
        if let error { throw error }
        guard let route = routes.first(where: { $0.id == id }) else { throw RepositoryError.notFound }
        return route
    }

    func fetchCommunityGrade(routeID: UUID) async throws -> CommunityGradeRecord? {
        if let error { throw error }
        return grades[routeID]
    }
}
