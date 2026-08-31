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
    let freshZones: [WallZone]
}

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var state: LoadableState<HomeDashboardData> = .initial

    private let environment: AppEnvironment

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    func load(favouriteGymID: GymID? = nil) async {
        state = .loading
        do {
            let gyms: [Gym]
            let routes: [ClimbingRoute]
            let entries: [LogbookEntry]
            do {
                async let gymRequest = environment.gymRepository.allGyms()
                async let routeRequest = environment.routeRepository.allRoutes()
                async let entryRequest = currentUserEntries()
                (gyms, routes, entries) = try await (gymRequest, routeRequest, entryRequest)
            } catch {
                #if DEBUG
                if environment.dataAvailability == .online {
                    // Cloud path failed – fallback to fixtures for guest demo
                    gyms = DevelopmentFixtures.gyms
                    routes = DevelopmentFixtures.routes
                    entries = (try? await currentUserEntries()) ?? []
                } else {
                    throw error
                }
                #else
                throw error
                #endif
            }
            let routesByID = Dictionary(uniqueKeysWithValues: routes.map { ($0.id, $0) })
            let zones: [WallZone]
            do {
                zones = try await environment.gymRepository.allWallZones()
            } catch {
                #if DEBUG
                if environment.dataAvailability == .online {
                    zones = DevelopmentFixtures.wallZones
                } else {
                    throw error
                }
                #else
                throw error
                #endif
            }
            let gymsByID = Dictionary(uniqueKeysWithValues: gyms.map { ($0.id, $0) })
            let zonesByID = Dictionary(uniqueKeysWithValues: zones.map { ($0.id, $0) })
            var projects: [HomeProjectItem] = entries.filter { $0.status == .projecting }.compactMap { entry -> HomeProjectItem? in
                guard let route = routesByID[entry.routeID],
                      let gym = gymsByID[route.gymID],
                      let zone = zonesByID[route.wallZoneID] else { return nil }
                return HomeProjectItem(entry: entry, route: route, gym: gym, wallZone: zone)
            }
            projects.sort { urgencyDays(for: $0.route) < urgencyDays(for: $1.route) }
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
            let freshZones = zones
                .filter { $0.latestResetDate != nil }
                .sorted { ($0.latestResetDate ?? .distantPast) > ($1.latestResetDate ?? .distantPast) }
            let data = HomeDashboardData(
                frequentGym: favouriteGymID.flatMap { id in gyms.first { $0.id == id } },
                projects: projects,
                resets: Array(resets.prefix(3)),
                recentRecords: Array(recent),
                freshZones: Array(freshZones.prefix(6))
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

    private func urgencyDays(for route: ClimbingRoute) -> Int {
        if let archive = route.expectedArchiveDate {
            let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: archive)).day ?? Int.max
            return days
        }
        // No archive estimate — less urgent than any dated reset
        return Int.max - 1
    }

    private func currentUserEntries() async throws -> [LogbookEntry] {
        guard let userID = environment.currentUserID() else { return [] }
        return try await environment.logbookRepository.entries(userID: userID)
    }
}
