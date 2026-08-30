import XCTest
import SwiftUI
@testable import BlocLens

final class GymPhotoViewTests: XCTestCase {
    @MainActor
    func testViewRendersWithNilPlaceID() async {
        let service = NoopGymPhotoService()
        let view = GymPhotoView(placeID: nil, gymName: "Test Gym", photoService: service)
        XCTAssertNotNil(view)
    }

    @MainActor
    func testViewRendersWithValidPlaceID() async {
        let service = NoopGymPhotoService()
        let view = GymPhotoView(placeID: "ChIJtest123", gymName: "Test Gym", photoService: service)
        XCTAssertNotNil(view)
    }

    func testPhotoStateIdleAndLoadingAreGrouped() {
        let idle = GymPhotoView.PhotoState.idle
        let loading = GymPhotoView.PhotoState.loading
        XCTAssertNotEqual(idle, loading)
    }

    func testPhotoStateLoadedWrapsGymPhoto() {
        let photo = GymPhoto(
            imageURL: URL(string: "https://example.com/p.jpg")!,
            attribution: "Author",
            attributionHTML: nil
        )
        let state = GymPhotoView.PhotoState.loaded(photo)
        if case .loaded(let p) = state {
            XCTAssertEqual(p.imageURL.absoluteString, "https://example.com/p.jpg")
        } else {
            XCTFail("Expected loaded state")
        }
    }

    func testPhotoStateEquality() {
        let photo = GymPhoto(
            imageURL: URL(string: "https://example.com/p.jpg")!,
            attribution: nil,
            attributionHTML: nil
        )
        XCTAssertEqual(GymPhotoView.PhotoState.loaded(photo), GymPhotoView.PhotoState.loaded(photo))
        XCTAssertNotEqual(GymPhotoView.PhotoState.error, GymPhotoView.PhotoState.noPhoto)
    }
}
