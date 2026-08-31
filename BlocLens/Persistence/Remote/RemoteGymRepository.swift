import Foundation

actor RemoteGymRepository: GymRepository {
    private let dataSource: any RemoteGymDataSource

    init(dataSource: any RemoteGymDataSource) {
        self.dataSource = dataSource
    }

    func allGyms() async throws -> [Gym] {
        async let gymRequest = dataSource.fetchGymSummaries()
        async let facilityRequest = dataSource.fetchFacilities()
        async let zoneRequest = dataSource.fetchWallZoneSummaries()
        let (records, facilities, zones) = try await (gymRequest, facilityRequest, zoneRequest)

        // Fetch hardSoft bands concurrently with graceful fallback
        var hardSoftByGymID: [UUID: HardSoftSummary] = [:]
        let ds = dataSource
        try await withThrowingTaskGroup(of: (UUID, HardSoftSummary).self) { group in
            for record in records {
                let recordID = record.id
                group.addTask {
                    do {
                        let bands = try await ds.fetchHardSoftBands(gymID: recordID)
                        let overall = try Self.overallHardSoft(from: bands)
                        return (recordID, overall)
                    } catch {
                        return (recordID, .insufficientData)
                    }
                }
            }
            for try await (gymID, summary) in group {
                hardSoftByGymID[gymID] = summary
            }
        }

        var gyms: [Gym] = []
        gyms.reserveCapacity(records.count)
        for record in records {
            try Task.checkCancellation()
            let overall = hardSoftByGymID[record.id] ?? .insufficientData
            do {
                gyms.append(try Self.domain(record, facilities: facilities, zones: zones, hardSoft: overall))
            } catch {
                // Skip gyms that fail mapping but don't fail whole load
                continue
            }
        }
        return gyms.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func gym(id: GymID) async throws -> Gym {
        let uuid = try Self.uuid(id, field: "gyms.id")
        let record = try await dataSource.fetchGymSummary(id: uuid)
        async let facilityRequest = dataSource.fetchFacilities()
        async let zoneRequest = dataSource.fetchWallZoneSummaries()
        let bands = try await dataSource.fetchHardSoftBands(gymID: uuid)
        let (facilities, zones) = try await (facilityRequest, zoneRequest)
        let overall = try Self.overallHardSoft(from: bands)
        return try Self.domain(record, facilities: facilities, zones: zones, hardSoft: overall)
    }

    func searchGyms(query: String) async throws -> [Gym] {
        let gyms = try await allGyms()
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return gyms }
        return gyms.filter {
            $0.name.localizedCaseInsensitiveContains(term)
                || $0.brandName.localizedCaseInsensitiveContains(term)
                || $0.suburb.localizedCaseInsensitiveContains(term)
        }
    }

    func wallZones(gymID: GymID) async throws -> [WallZone] {
        let uuid = try Self.uuid(gymID, field: "wall_zones.gym_id")
        let zones = try await dataSource.fetchWallZoneSummaries()
        return try zones
            .filter { $0.gymID == uuid }
            .map { try Self.domainZone($0) }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    func allWallZones() async throws -> [WallZone] {
        let zones = try await dataSource.fetchWallZoneSummaries()
        return try zones
            .map { try Self.domainZone($0) }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private static func overallHardSoft(from bands: [GymHardSoftBandRecord]) throws -> HardSoftSummary {
        do {
            return try GymHardSoftMapping.overallSummary(from: bands)
        } catch {
            throw RepositoryError.decodingFailure
        }
    }

    private static func domain(
        _ record: GymRecord,
        facilities: [GymFacilityRecord],
        zones: [WallZoneRecord],
        hardSoft: HardSoftSummary
    ) throws -> Gym {
        do {
            return try record.domain(facilities: facilities, wallZones: zones, hardSoft: hardSoft)
        } catch {
            throw RepositoryError.decodingFailure
        }
    }

    private static func domainZone(_ record: WallZoneRecord) throws -> WallZone {
        do {
            return try record.domain()
        } catch {
            throw RepositoryError.decodingFailure
        }
    }

    private static func uuid(_ id: GymID, field: String) throws -> UUID {
        guard let uuid = UUID(uuidString: id.rawValue) else {
            throw RepositoryError.notFound
        }
        return uuid
    }
}
