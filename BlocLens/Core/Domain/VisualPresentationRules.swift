import Foundation
import SwiftUI

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

    /// VoiceOver-friendly colour + shape (e.g. "Red diamond", "White circle") — grade+shape without relying on colour alone.
    @MainActor static func accessibilityLabel(for colourOrTag: String) -> String {
        let base = accessibilityName(for: colourOrTag)
        let shape = shapeName(for: colourOrTag)
        return shape.isEmpty ? base : "\(base) \(shape)"
    }

    @MainActor static func shapeName(for colourOrTag: String) -> String {
        let n = colourOrTag.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let token = BlocColor.routePalette.first(where: { $0.name.lowercased() == n }) { return token.shape.rawValue }
        if let token = BlocColor.routePalette.first(where: { n.contains($0.name.lowercased()) }) { return token.shape.rawValue }
        return ""
    }

    /// Grade + shape combined for VoiceOver on route rows (e.g. "V4 Blue circle").
    @MainActor static func gradeAndShapeLabel(grade: String?, colour: String) -> String {
        let label = accessibilityLabel(for: colour)
        if let grade, !grade.isEmpty { return "\(grade) \(label)" }
        return label
    }
}
