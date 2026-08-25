import Combine
import Foundation

nonisolated struct HomeProjectItem: Identifiable, Equatable, Sendable {
    var id: LogbookEntryID { entry.id }
    let entry: LogbookEntry
    let route: ClimbingRoute
}

nonisolated struct HomeResetItem: Identifiable, Equatable, Sendable {
    var id: GymID { gym.id }
    let gym: Gym
    let date: Date
}

nonisolated struct HomeRecordItem: Identifiable, Equatable, Sendable {
    var id: LogbookEntryID { entry.id }
    let entry: LogbookEntry
    let route: ClimbingRoute
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
            let projects = entries.filter { $0.status == .projecting }.compactMap { entry in
                routesByID[entry.routeID].map { HomeProjectItem(entry: entry, route: $0) }
            }
            let recent = entries.prefix(4).compactMap { entry in
                routesByID[entry.routeID].map { HomeRecordItem(entry: entry, route: $0) }
            }
            let resets = gyms.compactMap { gym in
                gym.latestResetDate.map { HomeResetItem(gym: gym, date: $0) }
            }.sorted { $0.date > $1.date }
            let data = HomeDashboardData(
                frequentGym: gyms.first { $0.id == DevelopmentFixtures.mockProfile.favouriteGymID } ?? gyms.first,
                projects: projects,
                resets: Array(resets.prefix(3)),
                recentRecords: Array(recent)
            )
            state = environment.scenario == .offlineWithCache ? .offlineWithCache(data) : .loaded(data)
        } catch RepositoryError.offlineNoCache {
            state = .offlineWithoutCache
        } catch let error as RepositoryError {
            state = .error(error)
        } catch {
            state = .error(.fixtureFailure)
        }
    }
}
