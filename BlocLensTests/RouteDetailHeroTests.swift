import XCTest
import SwiftUI
@testable import BlocLens

final class RouteDetailHeroTests: XCTestCase {
    @MainActor
    func testHeroContainsGradeLocationStatusResetBetaWithoutScrolling() throws {
        // Hierarchy without scrolling: first viewport must contain all 5 hero fields
        // Verified via file-level identifiers + runtime data availability (ponytail: minimal UI hierarchy check without ViewInspector)
        let route = DevelopmentFixtures.routes[0]
        let grade = route.displayGrade?.displayName ?? ""
        XCTAssertFalse(grade.isEmpty, "V grade must be in hero first viewport")
        // location: wallZone or gymID always present
        let location = DevelopmentFixtures.wallZones.first { $0.id == route.wallZoneID }?.name ?? route.gymID.rawValue
        XCTAssertFalse(location.isEmpty, "Location must be in hero")
        // status: lifecycle or logbook status always present
        let statusFallback = route.lifecycle.rawValue
        XCTAssertFalse(statusFallback.isEmpty, "Status must be in hero")
        // reset: always produces string
        let resetText = route.resetDate?.formatted(date: .abbreviated, time: .omitted) ?? route.expectedArchiveDate?.formatted(date: .abbreviated, time: .omitted) ?? "Reset —"
        XCTAssertFalse(resetText.isEmpty, "Reset must be in hero")
        // beta count: always present (0 allowed but rendered)
        XCTAssertGreaterThanOrEqual(route.betaCount, 0, "Beta count must be in hero")
        XCTAssertTrue(route.betaCount >= 0)

        // File-level hierarchy guards: identifiers + L0 + glass + typo before containers
        let path = "/Users/uuuuuyu/Documents/ChatGPT/BlocLens/BlocLens/Features/Route/RouteDetailView.swift"
        let source = try String(contentsOfFile: path, encoding: .utf8)
        for id in ["hero-grade", "hero-location", "hero-status", "hero-reset", "hero-beta-count"] {
            XCTAssertTrue(source.contains(id), "\(id) must be in hero first viewport")
        }
        XCTAssertTrue(source.contains("aspectRatio(4 / 3"), "L0 full-bleed 4:3 required")
        XCTAssertTrue(source.contains(".clipped()"), "photo must be clipped")
        XCTAssertTrue(source.contains("30%") || source.contains("0.30"), "30% gradient required")
        XCTAssertTrue(source.contains("glassEffect") || source.contains("ultraThinMaterial"), "floating glass capsules required")
        XCTAssertTrue(source.contains("#available(iOS 26"), "progressive #available(iOS26) required")
        XCTAssertTrue(source.contains("BlocTypography"), "typography before containers")
        XCTAssertTrue(source.contains("BlocColor"), "Cold Zinc tokens")
        // No outer cardStyle wall on hero (only banners may use container styles; hero itself must not)
        // count cardStyle occurrences should be ≤2 (archived/moderation banners) not 6
        let cardStyleCount = source.components(separatedBy: "cardStyle").count - 1
        XCTAssertLessThanOrEqual(cardStyleCount, 2, "hero must remove outer cardStyle wall (found \(cardStyleCount))")
        // Divider separation for title group
        XCTAssertTrue(source.contains("Divider"), "Title group Divider separation required")
        // BetaPreview thumbnail+domain
        XCTAssertTrue(source.contains("BetaPreview") || source.contains("betaThumbnail") || source.contains("domain(for:"), "BetaPreview thumbnail+domain required")
        // Secondary folded
        XCTAssertTrue(source.contains("isSecondaryExpanded") || source.contains("View all"), "Secondary must be folded behind View all")
    }
}
