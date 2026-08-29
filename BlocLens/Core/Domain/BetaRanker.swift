import Foundation

nonisolated enum BetaRanker {
    static func visibleLinks(
        _ links: [BetaLink],
        viewer: BetaViewerProfile?
    ) -> [BetaLink] {
        let visible = links.filter {
            $0.linkHealth == .healthy && $0.moderationState == .visible
        }

        guard let viewer,
              let viewerHeight = viewer.heightCentimetres,
              let viewerArmSpan = viewer.armSpanCentimetres else {
            return visible.sorted(by: rankWithoutBody)
        }

        return visible.sorted { lhs, rhs in
            let lhsFull = lhs.tags.contains(.fullSolution)
            let rhsFull = rhs.tags.contains(.fullSolution)
            if lhsFull != rhsFull {
                return lhsFull
            }
            if lhs.helpfulCount != rhs.helpfulCount {
                return lhs.helpfulCount > rhs.helpfulCount
            }
            let lhsDistance = bodyDistance(
                link: lhs,
                viewerHeight: viewerHeight,
                viewerArmSpan: viewerArmSpan
            )
            let rhsDistance = bodyDistance(
                link: rhs,
                viewerHeight: viewerHeight,
                viewerArmSpan: viewerArmSpan
            )
            if lhsDistance != rhsDistance {
                return lhsDistance < rhsDistance
            }
            return stableID(lhs, rhs)
        }
    }

    private static func rankWithoutBody(_ lhs: BetaLink, _ rhs: BetaLink) -> Bool {
        let lhsFull = lhs.tags.contains(.fullSolution)
        let rhsFull = rhs.tags.contains(.fullSolution)
        if lhsFull != rhsFull {
            return lhsFull
        }
        return helpfulThenStableID(lhs, rhs)
    }

    private static func bodyDistance(
        link: BetaLink,
        viewerHeight: Double,
        viewerArmSpan: Double
    ) -> Double {
        guard let height = link.contributorHeightCentimetres,
              let armSpan = link.contributorArmSpanCentimetres else {
            return .greatestFiniteMagnitude
        }
        return abs(height - viewerHeight) + abs(armSpan - viewerArmSpan)
    }

    private static func helpfulThenStableID(_ lhs: BetaLink, _ rhs: BetaLink) -> Bool {
        if lhs.helpfulCount != rhs.helpfulCount {
            return lhs.helpfulCount > rhs.helpfulCount
        }
        return stableID(lhs, rhs)
    }

    private static func stableID(_ lhs: BetaLink, _ rhs: BetaLink) -> Bool {
        lhs.id.rawValue < rhs.id.rawValue
    }
}
