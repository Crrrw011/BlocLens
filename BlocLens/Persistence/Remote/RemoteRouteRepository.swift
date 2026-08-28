import Foundation

actor RemoteRouteRepository: RouteRepository {
    private let dataSource: any RemoteRouteDataSource

    init(dataSource: any RemoteRouteDataSource) {
        self.dataSource = dataSource
    }

    func routes(wallZoneID: WallZoneID, filter: RouteFilter) async throws -> [ClimbingRoute] {
        let zoneUUID = try Self.uuid(wallZoneID, field: "routes.wall_zone_id")
        let records = try await dataSource.fetchRouteSummaries()
        let zoneRecords = records.filter { $0.wallZoneID == zoneUUID }
        return try await map(zoneRecords, filter: filter)
    }

    func route(id: ClimbingRouteID) async throws -> ClimbingRoute {
        let uuid = try Self.uuid(id, field: "routes.id")
        let record = try await dataSource.fetchRouteSummary(id: uuid)
        let grade = try await dataSource.fetchCommunityGrade(routeID: record.id)
            ?? CommunityGradeRecord(routeID: record.id, voteCount: 0, isDisplayEligible: false, medianVGrade: nil)
        return try Self.domain(record, communityGrade: grade)
    }

    func searchRoutes(query: String, includesArchived: Bool) async throws -> [ClimbingRoute] {
        let records = try await dataSource.fetchRouteSummaries()
        let filter = RouteFilter(query: query, gradeBand: .all, includesArchived: includesArchived)
        return try await map(records, filter: filter)
    }

    func suspectedDuplicates(for query: DuplicateRouteQuery) async throws -> [ClimbingRoute] {
        let gymUUID = try Self.uuid(query.gymID, field: "routes.gym_id")
        let zoneUUID = try Self.uuid(query.wallZoneID, field: "routes.wall_zone_id")
        let records = try await dataSource.fetchRouteSummaries()
        let candidates = records.filter {
            $0.gymID == gymUUID
                && $0.wallZoneID == zoneUUID
                && ($0.colour ?? "")
                    .localizedCaseInsensitiveCompare(query.colour) == .orderedSame
        }
        return try await map(candidates, filter: RouteFilter(includesArchived: true))
    }

    func allRoutes() async throws -> [ClimbingRoute] {
        let records = try await dataSource.fetchRouteSummaries()
        return try await map(records, filter: RouteFilter(includesArchived: true))
    }

    private func map(_ records: [RouteRecord], filter: RouteFilter) async throws -> [ClimbingRoute] {
        let grades = try await communityGrades(for: records)
        let routes = try records.map { record -> ClimbingRoute in
            let grade = grades[record.id]
                ?? CommunityGradeRecord(routeID: record.id, voteCount: 0, isDisplayEligible: false, medianVGrade: nil)
            return try Self.domain(record, communityGrade: grade)
        }
        return Self.apply(filter, to: routes)
    }

    private func communityGrades(for records: [RouteRecord]) async throws -> [UUID: CommunityGradeRecord] {
        var result: [UUID: CommunityGradeRecord] = [:]
        let concurrencyLimit = 8
        for chunk in stride(from: 0, to: records.count, by: concurrencyLimit) {
            try Task.checkCancellation()
            let slice = Array(records[chunk..<min(chunk + concurrencyLimit, records.count)])
            let pairs = try await withThrowingTaskGroup(of: (UUID, CommunityGradeRecord?).self) { group in
                for record in slice {
                    group.addTask { [dataSource] in
                        let grade = try await dataSource.fetchCommunityGrade(routeID: record.id)
                        return (record.id, grade)
                    }
                }
                var collected: [(UUID, CommunityGradeRecord?)] = []
                for try await pair in group {
                    collected.append(pair)
                }
                return collected
            }
            for (routeID, grade) in pairs {
                if let grade {
                    result[routeID] = grade
                }
            }
        }
        return result
    }

    private static func domain(_ record: RouteRecord, communityGrade: CommunityGradeRecord) throws -> ClimbingRoute {
        do {
            return try record.domain(communityGrade: communityGrade, photoReference: nil)
        } catch {
            throw RepositoryError.decodingFailure
        }
    }

    private static func uuid(_ id: ClimbingRouteID, field: String) throws -> UUID {
        guard let uuid = UUID(uuidString: id.rawValue) else {
            throw RepositoryError.notFound
        }
        return uuid
    }

    private static func uuid(_ id: GymID, field: String) throws -> UUID {
        guard let uuid = UUID(uuidString: id.rawValue) else {
            throw RepositoryError.notFound
        }
        return uuid
    }

    private static func uuid(_ id: WallZoneID, field: String) throws -> UUID {
        guard let uuid = UUID(uuidString: id.rawValue) else {
            throw RepositoryError.notFound
        }
        return uuid
    }

    private static func apply(_ filter: RouteFilter, to routes: [ClimbingRoute]) -> [ClimbingRoute] {
        routes.filter { route in
            let matchesLifecycle = filter.includesArchived || route.lifecycle == .active
            let matchesGrade = filter.gradeBand.contains(route.displayGrade)
            let term = filter.query.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesQuery = term.isEmpty
                || route.colour.localizedCaseInsensitiveContains(term)
                || route.displayGrade?.displayName.localizedCaseInsensitiveContains(term) == true
            return matchesLifecycle && matchesGrade && matchesQuery
        }
        .sorted { lhs, rhs in
            if lhs.lifecycle != rhs.lifecycle { return lhs.lifecycle == .active }
            let lhsGrade = lhs.displayGrade ?? .unknown
            let rhsGrade = rhs.displayGrade ?? .unknown
            if lhsGrade != rhsGrade { return lhsGrade < rhsGrade }
            return lhs.id.rawValue < rhs.id.rawValue
        }
    }
}
