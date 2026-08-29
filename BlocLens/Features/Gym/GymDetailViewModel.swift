import Combine
import Foundation

@MainActor
final class GymDetailViewModel: ObservableObject {
    @Published private(set) var state: LoadableState<[WallZone]> = .initial
    @Published private(set) var routesByZoneID: [WallZoneID: [ClimbingRoute]] = [:]
    @Published private(set) var freshZones: [WallZone] = []

    private let gym: Gym
    private let gymRepository: any GymRepository
    private let routeRepository: any RouteRepository

    init(gym: Gym, gymRepository: any GymRepository, routeRepository: any RouteRepository) {
        self.gym = gym
        self.gymRepository = gymRepository
        self.routeRepository = routeRepository
    }

    // Legacy single-repo init for previews/tests that don't need routes.
    convenience init(gym: Gym, repository: any GymRepository) {
        self.init(gym: gym, gymRepository: repository, routeRepository: MockRouteRepository())
    }

    func load() async {
        state = .loading
        do {
            async let zonesTask = gymRepository.wallZones(gymID: gym.id)
            async let routesTask = routeRepository.allRoutes()
            let zones = try await zonesTask
            let allRoutes = try await routesTask
            let sortedZones = zones.sorted { $0.sortOrder < $1.sortOrder }
            freshZones = sortedZones.sorted {
                ($0.latestResetDate ?? .distantPast) > ($1.latestResetDate ?? .distantPast)
            }
            var grouped: [WallZoneID: [ClimbingRoute]] = [:]
            for zone in sortedZones {
                let zoneRoutes = allRoutes.filter { $0.wallZoneID == zone.id && $0.lifecycle == .active }
                    .sorted { ($0.displayGrade ?? .unknown) < ($1.displayGrade ?? .unknown) }
                grouped[zone.id] = zoneRoutes
            }
            routesByZoneID = grouped
            state = sortedZones.isEmpty ? .empty : .loaded(sortedZones)
        } catch RepositoryError.offlineNoCache {
            state = .offlineWithoutCache
        } catch let error as RepositoryError {
            state = .error(error)
        } catch {
            state = .error(.fixtureFailure)
        }
    }
}
