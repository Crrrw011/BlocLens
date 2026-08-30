import XCTest
@testable import BlocLens

final class ProfileEditTests: XCTestCase {
    func testNewProfileHeightDefaultsTo170cm() {
        let state = ProfileEditState(profile: nil)
        XCTAssertEqual(state.heightCentimetres, 170)
    }

    func testNewProfileArmSpanDefaultsTo170cm() {
        let state = ProfileEditState(profile: nil)
        XCTAssertEqual(state.armSpanCentimetres, 170)
    }

    func testNewProfileHasHeightAndArmSpanTogglesOn() {
        let state = ProfileEditState(profile: nil)
        XCTAssertTrue(state.hasHeight)
        XCTAssertTrue(state.hasArmSpan)
    }

    func testSavedHeightNotOverwritten() {
        let profile = UserProfile(
            userID: UserID(rawValue: "test-user"),
            username: "test",
            heightCentimetres: 180,
            armSpanCentimetres: nil,
            regularGrade: nil,
            gradeSystem: nil,
            ydsGrade: nil,
            favouriteGymID: nil,
            isTrustedContributor: false,
            helpfulVotes: 0
        )
        let state = ProfileEditState(profile: profile)
        XCTAssertEqual(state.heightCentimetres, 180)
    }

    func testSavedArmSpanNotOverwritten() {
        let profile = UserProfile(
            userID: UserID(rawValue: "test-user"),
            username: "test",
            heightCentimetres: nil,
            armSpanCentimetres: 175,
            regularGrade: nil,
            gradeSystem: nil,
            ydsGrade: nil,
            favouriteGymID: nil,
            isTrustedContributor: false,
            helpfulVotes: 0
        )
        let state = ProfileEditState(profile: profile)
        XCTAssertEqual(state.armSpanCentimetres, 175)
    }

    func testExistingHeightPreservedWithNilArmSpan() {
        let profile = UserProfile(
            userID: UserID(rawValue: "test-user"),
            username: "test",
            heightCentimetres: 185,
            armSpanCentimetres: nil,
            regularGrade: nil,
            gradeSystem: nil,
            ydsGrade: nil,
            favouriteGymID: nil,
            isTrustedContributor: false,
            helpfulVotes: 0
        )
        let state = ProfileEditState(profile: profile)
        XCTAssertEqual(state.heightCentimetres, 185)
        XCTAssertNil(state.armSpanCentimetres)
        XCTAssertTrue(state.hasHeight)
        XCTAssertFalse(state.hasArmSpan)
    }

    func testRegularGradeNilShowsNotSureYet() {
        let state = ProfileEditState(profile: nil)
        XCTAssertTrue(state.isNotSureYet)
    }

    func testNotSureYetSavesAsNil() {
        var state = ProfileEditState(profile: nil)
        state.isNotSureYet = true
        state.vGrade = .v5
        let saved = state.toSavedGrade()
        XCTAssertNil(saved.regularGrade)
        XCTAssertNil(saved.gradeSystem)
        XCTAssertNil(saved.ydsGrade)
    }

    func testSpecificGradeSavesCorrectly() {
        var state = ProfileEditState(profile: nil)
        state.isNotSureYet = false
        state.vGrade = .v5
        let saved = state.toSavedGrade()
        XCTAssertEqual(saved.regularGrade, .v5)
        XCTAssertEqual(saved.gradeSystem, .vScale)
    }

    func testNotSureYetDoesNotAffectGradeStats() {
        var state = ProfileEditState(profile: nil)
        state.isNotSureYet = true
        let saved = state.toSavedGrade()
        XCTAssertNil(saved.regularGrade, "Not sure yet must not produce a real grade for stats")
    }
}
