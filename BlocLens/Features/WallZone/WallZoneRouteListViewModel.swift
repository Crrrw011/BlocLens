import Combine

@MainActor
final class WallZoneRouteListViewModel: ObservableObject {
    @Published private(set) var state: LoadableState<[ClimbingRoute]> = .initial
    @Published private(set) var statusByRouteID: [ClimbingRouteID: LogbookStatus] = [:]
    @Published var filter = RouteFilter()

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
            async let routeRequest = repository.routes(wallZoneID: wallZone.id, filter: filter)
            async let entryRequest = logbookRepository.entries(userID: userID)
            let (routes, entries) = try await (routeRequest, entryRequest)
            statusByRouteID = Dictionary(uniqueKeysWithValues: entries.map { ($0.routeID, $0.status) })
            state = routes.isEmpty ? .empty : .loaded(routes)
        } catch RepositoryError.offlineNoCache {
            state = .offlineWithoutCache
        } catch let error as RepositoryError {
            state = .error(error)
        } catch {
            state = .error(.fixtureFailure)
        }
    }
}
