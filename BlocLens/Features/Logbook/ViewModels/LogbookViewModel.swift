import Combine
import Foundation

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
    @Published var statusFilter: LogbookStatus?
    @Published var recentOnly = false

    private let environment: AppEnvironment

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    func filteredRecords(from data: LogbookDashboardData, referenceDate: Date = Date()) -> [LogbookRecordItem] {
        data.recentRecords.filter { item in
            let matchesStatus = statusFilter == nil || item.entry.status == statusFilter
            let matchesDate = !recentOnly || item.entry.date >= referenceDate.addingTimeInterval(-30 * 24 * 60 * 60)
            return matchesStatus && matchesDate
        }
    }

    func load() async {
        state = .loading
        do {
            async let routeRequest = environment.routeRepository.allRoutes()
            async let entryRequest = currentUserEntries()
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
            state = environment.dataAvailability == .offlineCached ? .offlineWithCache(data) : .loaded(data)
        } catch RepositoryError.offlineNoCache {
            state = .offlineWithoutCache
        } catch let error as RepositoryError {
            state = .error(error)
        } catch {
            state = .error(.fixtureFailure)
        }
    }

    private func currentUserEntries() async throws -> [LogbookEntry] {
        guard let userID = environment.currentUserID() else { return [] }
        return try await environment.logbookRepository.entries(userID: userID)
    }
}
