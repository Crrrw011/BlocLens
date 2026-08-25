import Foundation

nonisolated enum BetaRevealState: Equatable, Sendable {
    case hidden
    case revealed

    var isRevealed: Bool { self == .revealed }

    mutating func reveal() {
        self = .revealed
    }
}

nonisolated enum RoutePresentationRules {
    static func isCurrent(_ route: ClimbingRoute) -> Bool {
        route.lifecycle == .active
    }

    static func showsArchivedBanner(_ route: ClimbingRoute) -> Bool {
        route.lifecycle == .archived
    }

    static func showsEstimateOnly(_ route: ClimbingRoute) -> Bool {
        route.expectedArchiveDate != nil && route.isArchiveDateEstimated
    }
}

nonisolated enum RouteColourPresentation {
    static func accessibilityName(for colourOrTag: String) -> String {
        colourOrTag.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
