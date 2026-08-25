import Foundation

nonisolated struct GymFilterOptions: Equatable, Sendable {
    var openNow = false
    var facilities: Set<GymFacility> = []
    var hasBeta = false
    var recentlyReset = false

    var isActive: Bool {
        openNow || !facilities.isEmpty || hasBeta || recentlyReset
    }

    var activeCount: Int {
        (openNow ? 1 : 0) + facilities.count + (hasBeta ? 1 : 0) + (recentlyReset ? 1 : 0)
    }
}

nonisolated enum GymFilterService {
    static func filter(
        _ gyms: [Gym],
        options: GymFilterOptions,
        referenceDate: Date,
        mockOpenGymIDs: Set<GymID>
    ) -> [Gym] {
        gyms.filter { gym in
            let matchesOpen = !options.openNow || mockOpenGymIDs.contains(gym.id)
            let matchesFacilities = options.facilities.isSubset(of: Set(gym.facilities))
            let matchesBeta = !options.hasBeta || gym.betaCount > 0
            let recentThreshold = referenceDate.addingTimeInterval(-14 * 24 * 60 * 60)
            let matchesReset = !options.recentlyReset
                || gym.latestResetDate.map { $0 >= recentThreshold && $0 <= referenceDate } == true
            return matchesOpen && matchesFacilities && matchesBeta && matchesReset
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
