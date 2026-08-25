import Combine
import Foundation

nonisolated struct HomeProjectItem: Identifiable, Equatable, Sendable {
    var id: LogbookEntryID { entry.id }
    let entry: LogbookEntry
    let route: ClimbingRoute
    let gym: Gym
    let wallZone: WallZone
}

nonisolated struct HomeResetItem: Identifiable, Equatable, Sendable {
    var id: GymID { gym.id }
    let gym: Gym
    let date: Date
    let wallZone: WallZone?
}

nonisolated struct HomeRecordItem: Identifiable, Equatable, Sendable {
    var id: LogbookEntryID { entry.id }
    let entry: LogbookEntry
    let route: ClimbingRoute
    let gym: Gym
    let wallZone: WallZone
}

nonisolated struct HomeDashboardData: Equatable, Sendable {
    let frequentGym: Gym?
    let projects: [HomeProjectItem]
    let resets: [HomeResetItem]
    let recentRecords: [HomeRecordItem]
}

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var state: LoadableState<HomeDashboardData> = .initial

    private let environment: AppEnvironment

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    func load() async {
        state = .loading
        do {
            async let gymRequest = environment.gymRepository.allGyms()
            async let routeRequest = environment.routeRepository.allRoutes()
            async let entryRequest = environment.logbookRepository.entries(userID: environment.currentUserID)
            let (gyms, routes, entries) = try await (gymRequest, routeRequest, entryRequest)
            let routesByID = Dictionary(uniqueKeysWithValues: routes.map { ($0.id, $0) })
            var zones: [WallZone] = []
            for gym in gyms {
                zones.append(contentsOf: try await environment.gymRepository.wallZones(gymID: gym.id))
            }
            let gymsByID = Dictionary(uniqueKeysWithValues: gyms.map { ($0.id, $0) })
            let zonesByID = Dictionary(uniqueKeysWithValues: zones.map { ($0.id, $0) })
            let projects: [HomeProjectItem] = entries.filter { $0.status == .projecting }.compactMap { entry -> HomeProjectItem? in
                guard let route = routesByID[entry.routeID],
                      let gym = gymsByID[route.gymID],
                      let zone = zonesByID[route.wallZoneID] else { return nil }
                return HomeProjectItem(entry: entry, route: route, gym: gym, wallZone: zone)
            }
            let recent: [HomeRecordItem] = entries.prefix(4).compactMap { entry -> HomeRecordItem? in
                guard let route = routesByID[entry.routeID],
                      let gym = gymsByID[route.gymID],
                      let zone = zonesByID[route.wallZoneID] else { return nil }
                return HomeRecordItem(entry: entry, route: route, gym: gym, wallZone: zone)
            }
            let resets = gyms.compactMap { gym in
                gym.latestResetDate.map { date in
                    let zone = zones.filter { $0.gymID == gym.id && $0.latestResetDate != nil }
                        .max { ($0.latestResetDate ?? .distantPast) < ($1.latestResetDate ?? .distantPast) }
                    return HomeResetItem(gym: gym, date: date, wallZone: zone)
                }
            }.sorted { $0.date > $1.date }
            let data = HomeDashboardData(
                frequentGym: gyms.first { $0.id == DevelopmentFixtures.mockProfile.favouriteGymID } ?? gyms.first,
                projects: projects,
                resets: Array(resets.prefix(3)),
                recentRecords: Array(recent)
            )
            state = environment.dataAvailability == .offlineCached ? .offlineWithCache(data) : .loaded(data)
        } catch RepositoryError.offlineNoCache {
            state = .offlineWithoutCache
        } catch let error as RepositoryError {
            state = .error(error)
        } catch {
            state = .error(.fixtureFailure)
        }
    }
}
