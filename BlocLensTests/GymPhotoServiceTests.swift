import XCTest
@testable import BlocLens

final class GymPhotoServiceTests: XCTestCase {
    func testGymDecodesGooglePlaceID() throws {
        let json = """
        {
            "id": "00000000-0000-0000-0000-000000000001",
            "name": "Test Gym",
            "brand_name": "Test Brand",
            "latitude": -33.8688,
            "longitude": 151.2093,
            "suburb": "Sydney",
            "state": "NSW",
            "is_verified": true,
            "data_source": "official",
            "beta_count": 5,
            "latest_reset_date": null,
            "google_place_id": "ChIJ1234567890"
        }
        """.data(using: .utf8)!
        let record = try JSONDecoder().decode(GymRecord.self, from: json)
        XCTAssertEqual(record.googlePlaceID, "ChIJ1234567890")
    }

    func testGymDecodesNilGooglePlaceID() throws {
        let json = """
        {
            "id": "00000000-0000-0000-0000-000000000002",
            "name": "Test Gym 2",
            "latitude": -33.8688,
            "longitude": 151.2093,
            "suburb": "Sydney",
            "state": "NSW",
            "is_verified": false,
            "data_source": "community"
        }
        """.data(using: .utf8)!
        let record = try JSONDecoder().decode(GymRecord.self, from: json)
        XCTAssertNil(record.googlePlaceID)
    }
}
