import Combine

@MainActor
final class WallZoneRouteListViewModel: ObservableObject {
    @Published private(set) var state: LoadableState<[ClimbingRoute]> = .initial
    @Published private(set) var statusByRouteID: [ClimbingRouteID: LogbookStatus] = [:]
    @Published private(set) var archivedRoutes: [ClimbingRoute] = []
    @Published var options = RouteListOptions()

    private let wallZone: WallZone
    private let repository: any RouteRepository
    private let logbookRepository: any LogbookRepository
    private let userID: UserID

    init(
        wallZone: WallZone,
        repository: any RouteRepository,
        logbookRepository: any LogbookRepository,
        userID: UserID
    ) {
        self.wallZone = wallZone
        self.repository = repository
        self.logbookRepository = logbookRepository
        self.userID = userID
    }

    func load() async {
        state = .loading
        do {
            async let routeRequest = repository.routes(
                wallZoneID: wallZone.id,
                filter: RouteFilter(query: "", gradeBand: .all, includesArchived: true)
            )
            async let entryRequest = logbookRepository.entries(userID: userID)
            let (routes, entries) = try await (routeRequest, entryRequest)
            statusByRouteID = Dictionary(uniqueKeysWithValues: entries.map { ($0.routeID, $0.status) })
            let current = RouteListPresentation.currentRoutes(routes, options: options)
            archivedRoutes = RouteListPresentation.archivedRoutes(routes, options: options)
            state = current.isEmpty && archivedRoutes.isEmpty ? .empty : .loaded(current)
        } catch RepositoryError.offlineNoCache {
            state = .offlineWithoutCache
        } catch let error as RepositoryError {
            state = .error(error)
        } catch {
            state = .error(.fixtureFailure)
        }
    }

    func clearFilters() async {
        options = RouteListOptions()
        await load()
    }
}
