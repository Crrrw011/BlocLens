import Combine
import Foundation

@MainActor
final class MapViewModel: ObservableObject {
    @Published private(set) var state: LoadableState<[Gym]> = .initial
    @Published var filterOptions = GymFilterOptions()

    private let repository: any GymRepository
    private let dataAvailability: DataAvailability
    private var allLoadedGyms: [Gym] = []

    private static let referenceDate = Date(timeIntervalSince1970: 1_787_623_200)
    private static let mockOpenGymIDs: Set<GymID> = ["urban-climb-west-end", "nine-degrees-enoggera"]

    init(repository: any GymRepository, dataAvailability: DataAvailability = .online) {
        self.repository = repository
        self.dataAvailability = dataAvailability
    }

    func load() async {
        state = .loading
        do {
            let gyms = try await repository.allGyms()
            allLoadedGyms = gyms
            guard !gyms.isEmpty else {
                state = .empty
                return
            }
            applyFilters()
        } catch RepositoryError.offlineNoCache {
            state = .offlineWithoutCache
        } catch let error as RepositoryError {
            state = .error(error)
        } catch {
            state = .error(.fixtureFailure)
        }
    }

    func applyFilters() {
        let gyms = GymFilterService.filter(
            allLoadedGyms,
            options: filterOptions,
            referenceDate: Self.referenceDate,
            mockOpenGymIDs: Self.mockOpenGymIDs
        )
        guard !gyms.isEmpty else {
            state = .empty
            return
        }
        state = dataAvailability == .offlineCached ? .offlineWithCache(gyms) : .loaded(gyms)
    }

    func clearFilters() {
        filterOptions = GymFilterOptions()
        applyFilters()
    }
}

nonisolated enum LocalSearchResult: Identifiable, Equatable, Sendable {
    case gym(Gym)
    case wallZone(WallZone, gym: Gym)
    case route(ClimbingRoute, wallZone: WallZone, gym: Gym)

    var id: String {
        switch self {
        case .gym(let gym): "gym-\(gym.id.rawValue)"
        case .wallZone(let zone, _): "zone-\(zone.id.rawValue)"
        case .route(let route, _, _): "route-\(route.id.rawValue)"
        }
    }
}

@MainActor
final class LocalSearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var gradeBand: GradeBand = .all
    @Published var includesArchived = false
    @Published private(set) var results: [LocalSearchResult] = []
    @Published private(set) var googlePlaces: [GooglePlaceResult] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: RepositoryError?

    private let gymRepository: any GymRepository
    private let routeRepository: any RouteRepository
    private let googlePlacesClient: any GooglePlacesClient

    init(
        gymRepository: any GymRepository,
        routeRepository: any RouteRepository,
        googlePlacesClient: any GooglePlacesClient
    ) {
        self.gymRepository = gymRepository
        self.routeRepository = routeRepository
        self.googlePlacesClient = googlePlacesClient
    }

    func search() async {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty || gradeBand != .all else {
            results = []
            googlePlaces = []
            return
        }
        isLoading = true
        error = nil
        defer { isLoading = false }

        async let gymRequest = gymRepository.allGyms()
        async let zoneRequest = gymRepository.allWallZones()
        async let routeRequest = routeRepository.searchRoutes(query: term, includesArchived: includesArchived)
        async let placesRequest = searchPlaces(term)

        do {
            let (gyms, zones, foundRoutes, places) = try await (gymRequest, zoneRequest, routeRequest, placesRequest)
            let gymsByID = Dictionary(uniqueKeysWithValues: gyms.map { ($0.id, $0) })
            let zonesByID = Dictionary(uniqueKeysWithValues: zones.map { ($0.id, $0) })

            let gymResults = gyms.filter {
                term.isEmpty
                    || $0.name.localizedCaseInsensitiveContains(term)
                    || $0.suburb.localizedCaseInsensitiveContains(term)
            }.map(LocalSearchResult.gym)

            let zoneResults = zones.compactMap { zone -> LocalSearchResult? in
                guard !term.isEmpty,
                      zone.name.localizedCaseInsensitiveContains(term),
                      let gym = gymsByID[zone.gymID] else { return nil }
                return .wallZone(zone, gym: gym)
            }

            let routeResults = foundRoutes.compactMap { route -> LocalSearchResult? in
                guard gradeBand.contains(route.displayGrade),
                      let zone = zonesByID[route.wallZoneID],
                      let gym = gymsByID[route.gymID] else { return nil }
                return .route(route, wallZone: zone, gym: gym)
            }
            results = gymResults + zoneResults + routeResults
            googlePlaces = places
        } catch let repositoryError as RepositoryError {
            results = []
            googlePlaces = []
            error = repositoryError
        } catch {
            results = []
            googlePlaces = []
            self.error = .fixtureFailure
        }
    }

    private func searchPlaces(_ term: String) async throws -> [GooglePlaceResult] {
        guard !term.isEmpty else { return [] }
        do {
            return try await googlePlacesClient.searchText(term)
        } catch {
            return []
        }
    }

    func clear() {
        query = ""
        gradeBand = .all
        includesArchived = false
        results = []
        googlePlaces = []
        error = nil
    }
}
