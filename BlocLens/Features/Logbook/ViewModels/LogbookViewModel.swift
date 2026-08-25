import Combine

nonisolated struct LogbookRecordItem: Identifiable, Equatable, Sendable {
    var id: LogbookEntryID { entry.id }
    let entry: LogbookEntry
    let route: ClimbingRoute
}

nonisolated struct LogbookDashboardData: Equatable, Sendable {
    let statistics: LogbookStatistics
    let projects: [LogbookRecordItem]
    let recentRecords: [LogbookRecordItem]
}

@MainActor
final class LogbookViewModel: ObservableObject {
    @Published private(set) var state: LoadableState<LogbookDashboardData> = .initial

    private let environment: AppEnvironment

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    func load() async {
        state = .loading
        do {
            async let routeRequest = environment.routeRepository.allRoutes()
            async let entryRequest = environment.logbookRepository.entries(userID: environment.currentUserID)
            let (routes, entries) = try await (routeRequest, entryRequest)
            let routesByID = Dictionary(uniqueKeysWithValues: routes.map { ($0.id, $0) })
            let items = entries.compactMap { entry in
                routesByID[entry.routeID].map { LogbookRecordItem(entry: entry, route: $0) }
            }
            let data = LogbookDashboardData(
                statistics: LogbookStatistics.calculate(entries: entries, routesByID: routesByID),
                projects: items.filter { $0.entry.status == .projecting },
                recentRecords: items
            )
            guard !items.isEmpty else {
                state = .empty
                return
            }
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
