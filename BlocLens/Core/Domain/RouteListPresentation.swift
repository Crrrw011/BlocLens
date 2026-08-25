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
                || route.colourOrTag.localizedCaseInsensitiveContains(term)
                || route.officialGrade?.displayName.localizedCaseInsensitiveContains(term) == true
            return matchesQuery
                && options.gradeBand.contains(route.officialGrade)
                && (!options.hasBeta || route.betaCount > 0)
        }
        .sorted { lhs, rhs in
            switch options.sort {
            case .newest:
                let lhsDate = lhs.resetDate ?? .distantPast
                let rhsDate = rhs.resetDate ?? .distantPast
                if lhsDate != rhsDate { return lhsDate > rhsDate }
            case .grade:
                let lhsGrade = lhs.officialGrade ?? .unknown
                let rhsGrade = rhs.officialGrade ?? .unknown
                if lhsGrade != rhsGrade { return lhsGrade < rhsGrade }
            case .mostBeta:
                if lhs.betaCount != rhs.betaCount { return lhs.betaCount > rhs.betaCount }
            }
            return lhs.id.rawValue < rhs.id.rawValue
        }
    }
}
