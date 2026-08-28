import Foundation

nonisolated enum RouteSort: String, CaseIterable, Sendable {
    case newest
    case grade
    case mostBeta
}

nonisolated struct RouteListOptions: Equatable, Sendable {
    var query = ""
    var gradeBand: GradeBand = .all
    var hasBeta = false
    var sort: RouteSort = .newest

    var activeFilterCount: Int {
        (query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : 1)
            + (gradeBand == .all ? 0 : 1)
            + (hasBeta ? 1 : 0)
    }

    var hasActiveFilters: Bool { activeFilterCount > 0 }
}

nonisolated enum RouteListPresentation {
    static func currentRoutes(_ routes: [ClimbingRoute], options: RouteListOptions) -> [ClimbingRoute] {
        filterAndSort(routes.filter { $0.lifecycle == .active }, options: options)
    }

    static func archivedRoutes(_ routes: [ClimbingRoute], options: RouteListOptions) -> [ClimbingRoute] {
        filterAndSort(routes.filter { $0.lifecycle == .archived }, options: options)
    }

    private static func filterAndSort(_ routes: [ClimbingRoute], options: RouteListOptions) -> [ClimbingRoute] {
        let term = options.query.trimmingCharacters(in: .whitespacesAndNewlines)
        return routes.filter { route in
            let matchesQuery = term.isEmpty
                || route.colour.localizedCaseInsensitiveContains(term)
                || route.displayGrade?.displayName.localizedCaseInsensitiveContains(term) == true
            return matchesQuery
                && options.gradeBand.contains(route.displayGrade)
                && (!options.hasBeta || route.betaCount > 0)
        }
        .sorted { lhs, rhs in
            switch options.sort {
            case .newest:
                let lhsDate = lhs.resetDate ?? .distantPast
                let rhsDate = rhs.resetDate ?? .distantPast
                if lhsDate != rhsDate { return lhsDate > rhsDate }
            case .grade:
                let lhsGrade = lhs.displayGrade ?? .unknown
                let rhsGrade = rhs.displayGrade ?? .unknown
                if lhsGrade != rhsGrade { return lhsGrade < rhsGrade }
            case .mostBeta:
                if lhs.betaCount != rhs.betaCount { return lhs.betaCount > rhs.betaCount }
            }
            return lhs.id.rawValue < rhs.id.rawValue
        }
    }
}
