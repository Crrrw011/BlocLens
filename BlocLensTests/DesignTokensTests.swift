import XCTest
import SwiftUI
@testable import BlocLens

final class DesignTokensTests: XCTestCase {
    func testRoutePaletteHas12ColoursWithShape() {
        XCTAssertEqual(BlocColor.routePalette.count, 12)
        for c in BlocColor.routePalette { XCTAssertNotNil(c.shape) }
    }

    func testGradeTypographyIsBoldTabular() {
        XCTAssertEqual(BlocTypography.gradeWeight, .bold)
        XCTAssertTrue(String(describing: BlocTypography.grade).contains("MonospacedDigit"))
    }

    func testSpacingAndRadiusTokensExist() {
        XCTAssertEqual(BlocSpacing.sectionGap, 40)
        XCTAssertEqual(BlocRadius.container, 20)
        XCTAssertEqual(BlocRadius.sheet, 24)
        XCTAssertEqual(BlocRadius.capsule, 999)
    }

    func testGlassMaterialExists() {
        _ = BlocMaterial.glass
    }

    func testHapticsExists() {
        _ = BlocHaptics.selection
    }
}
