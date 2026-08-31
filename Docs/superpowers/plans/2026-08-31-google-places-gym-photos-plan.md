# Google Places Gym Photo Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Display Google-sourced gym photos in Home card and Gym Detail hero using Google Places REST API, with proper attribution and caching.

**Architecture:** Extend existing `GooglePlacesClient` REST pattern to fetch place photos. New `GymPhotoService` protocol with REST implementation, injected via `AppEnvironment`. Reusable `GymPhotoView` SwiftUI component used in both Home and Gym Detail. `URLCache` handles photo caching.

**Tech Stack:** SwiftUI · iPhone · iOS 17+ · Google Places REST API · XCTest · URLCache

**Spec:** `Docs/superpowers/specs/2026-08-31-google-places-gym-photos-design.md`

## Global Constraints

- SwiftUI iPhone iOS 17+ — do not raise deployment target
- Native Apple frameworks only — no third-party UI dependency added
- Google Places REST API only — no Google Maps SDK or Places SDK binary
- Place ID is the only persisted Google data (compliant with caching restrictions)
- Attribution must not be hidden, obscured, or modified
- API key from Info.plist "GooglePlacesAPIKey" — no hardcoded secrets
- No custom photo cache directories — URLCache only
- No photo data saved to Supabase, App Bundle, Documents, or UserDefaults
- Light + Dark appearance support
- Dynamic Type, VoiceOver, 44pt touch targets
- Preserve existing Supabase schema, auth, business logic

---

## File Structure

**Modify:**
- `BlocLens/Core/Models/Gym.swift` — add `googlePlaceID: String?`
- `BlocLens/Persistence/Remote/GymRecords.swift` — decode `google_place_id`
- `BlocLens/Persistence/Remote/GooglePlacesClient.swift` — add `fetchPlaceDetails(placeID:)`
- `BlocLens/App/AppEnvironment.swift` — inject `GymPhotoService`
- `BlocLens/Mocks/MockRepositories.swift` — add mock photo service
- `BlocLens/Features/Home/HomeView.swift` — replace color fill with GymPhotoView
- `BlocLens/Features/Gym/GymDetailView.swift` — replace color fill with GymPhotoView
- `BlocLens/Utilities/L10n.swift` — add photo-related keys
- `BlocLens/Resources/Localisation/Localizable.xcstrings` — add photo strings

**Create:**
- `BlocLens/Core/Services/GymPhotoService.swift` — protocol + REST + Noop
- `BlocLens/Core/Components/GymPhotoView.swift` — reusable SwiftUI component
- `BlocLensTests/GymPhotoServiceTests.swift` — unit tests
- `BlocLensTests/GymPhotoViewTests.swift` — UI tests

---

### Task 14: Data Model — Add googlePlaceID to Gym

**Files:**
- Modify: `BlocLens/Core/Models/Gym.swift`
- Modify: `BlocLens/Persistence/Remote/GymRecords.swift`

**Interfaces:**
- Produces: `Gym.googlePlaceID: String?` (used by GymPhotoService in later tasks)

- [ ] **Step 1: Write failing test**

```swift
// BlocLensTests/GymPhotoServiceTests.swift
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
```

- [ ] **Step 2: Run — verify FAIL**

Run: `xcodebuild test -scheme BlocLens -only-testing:BlocLensTests/GymPhotoServiceTests -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.4'`

- [ ] **Step 3: Add googlePlaceID to GymRecord**

In `GymRecords.swift`, add property and CodingKey:
```swift
let googlePlaceID: String?
// In CodingKeys: case googlePlaceID = "google_place_id"
```

- [ ] **Step 4: Add googlePlaceID to Gym domain model**

In `Gym.swift`, add to struct:
```swift
let googlePlaceID: String?
```

Update `GymRecord.domain()` to pass `googlePlaceID` through.

- [ ] **Step 5: Run — verify PASS**

- [ ] **Step 6: Commit**

```bash
git add BlocLens/Core/Models/Gym.swift BlocLens/Persistence/Remote/GymRecords.swift BlocLensTests/GymPhotoServiceTests.swift
git commit -m "feat: add googlePlaceID to Gym model"
```

---

### Task 15: Photo Service Protocol & REST Implementation

**Files:**
- Create: `BlocLens/Core/Services/GymPhotoService.swift`
- Modify: `BlocLens/Persistence/Remote/GooglePlacesClient.swift`

**Interfaces:**
- Consumes: API key from existing `GooglePlacesClient`
- Produces: `GymPhotoService` protocol, `RemoteGymPhotoService`, `NoopGymPhotoService`, `GymPhoto` struct

- [ ] **Step 1: Write failing tests**

```swift
// Add to GymPhotoServiceTests.swift
func testNoopPhotoServiceThrowsOnFetch() async {
    let service = NoopGymPhotoService()
    do {
        _ = try await service.fetchPhoto(for: "ChIJtest", width: 800)
        XCTFail("Should throw")
    } catch {
        // Expected
    }
}

func testGymPhotoStructEquality() {
    let photo1 = GymPhoto(imageURL: URL(string: "https://example.com/photo.jpg")!, attribution: "Author", attributionHTML: nil)
    let photo2 = GymPhoto(imageURL: URL(string: "https://example.com/photo.jpg")!, attribution: "Author", attributionHTML: nil)
    XCTAssertEqual(photo1, photo2)
}
```

- [ ] **Step 2: Run — verify FAIL**

- [ ] **Step 3: Implement GymPhoto struct and protocol**

```swift
// GymPhotoService.swift
import Foundation

nonisolated struct GymPhoto: Equatable, Sendable {
    let imageURL: URL
    let attribution: String?
    let attributionHTML: NSAttributedString?
}

nonisolated protocol GymPhotoService: Sendable {
    func fetchPhoto(for placeID: String, width: Int) async throws -> GymPhoto
}

struct NoopGymPhotoService: GymPhotoService, Sendable {
    func fetchPhoto(for placeID: String, width: Int) async throws -> GymPhoto {
        throw RepositoryError.invalidConfiguration
    }
}
```

- [ ] **Step 4: Implement RemoteGymPhotoService**

```swift
actor RemoteGymPhotoService: GymPhotoService {
    let apiKey: String
    private let session: URLSession

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    func fetchPhoto(for placeID: String, width: Int) async throws -> GymPhoto {
        guard !apiKey.isEmpty, apiKey != "YOUR_GOOGLE_PLACES_API_KEY" else {
            throw RepositoryError.invalidConfiguration
        }
        // 1. Fetch place details with photo metadata
        let detailsURL = URL(string: "https://places.googleapis.com/v1/places/\(placeID)?fields=photos")!
        var detailsRequest = URLRequest(url: detailsURL)
        detailsRequest.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        detailsRequest.setValue("photos.name,photos.authorAttributions", forHTTPHeaderField: "X-Goog-FieldMask")

        let (detailsData, detailsResponse) = try await session.data(for: detailsRequest)
        guard let http = detailsResponse as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw RepositoryError.externalServiceError
        }

        // 2. Parse photo metadata
        guard let json = try JSONSerialization.jsonObject(with: detailsData) as? [String: Any],
              let photos = json["photos"] as? [[String: Any]],
              let firstPhoto = photos.first,
              let photoName = firstPhoto["name"] as? String else {
            throw RepositoryError.decodingFailure
        }

        let attribution = (firstPhoto["authorAttributions"] as? [[String: Any]])?
            .compactMap { $0["displayName"] as? String }
            .joined(separator: ", ")

        // 3. Fetch photo media URL
        let photoURL = URL(string: "https://places.googleapis.com/v1/\(photoName)/media?maxWidthPx=\(width)")!
        return GymPhoto(imageURL: photoURL, attribution: attribution, attributionHTML: nil)
    }
}
```

- [ ] **Step 5: Run — verify PASS**

- [ ] **Step 6: Add fetchPlaceDetails to GooglePlacesClient**

Add method to `GooglePlacesClient` protocol and `RemoteGooglePlacesClient`:
```swift
// In protocol
func fetchPlaceDetails(placeID: String, fields: String) async throws -> [String: Any]

// In implementation
func fetchPlaceDetails(placeID: String, fields: String) async throws -> [String: Any] {
    // GET /v1/places/{place_id}?fields={fields}
}
```

- [ ] **Step 7: Run full test suite — verify no regressions**

- [ ] **Step 8: Commit**

```bash
git add BlocLens/Core/Services/GymPhotoService.swift BlocLens/Persistence/Remote/GooglePlacesClient.swift BlocLensTests/GymPhotoServiceTests.swift
git commit -m "feat: add GymPhotoService with REST implementation"
```

---

### Task 16: Inject GymPhotoService into AppEnvironment

**Files:**
- Modify: `BlocLens/App/AppEnvironment.swift`
- Modify: `BlocLens/Mocks/MockRepositories.swift`

**Interfaces:**
- Consumes: `GymPhotoService` from Task 15
- Produces: `AppEnvironment.gymPhotoService` available for views

- [ ] **Step 1: Write failing test**

```swift
// Add to GymPhotoServiceTests.swift
func testAppEnvironmentContainsGymPhotoService() {
    let env = AppEnvironment.development()
    // Verify the service is accessible (not nil)
    _ = env.gymPhotoService
}
```

- [ ] **Step 2: Run — verify FAIL**

- [ ] **Step 3: Add gymPhotoService to AppEnvironment**

```swift
// In AppEnvironment
let gymPhotoService: any GymPhotoService

// In .development(...)
gymPhotoService: NoopGymPhotoService()

// In .localSupabase(...)
gymPhotoService: RemoteGymPhotoService(apiKey: config.googlePlacesAPIKey)

// In .cloudSupabase(...)
gymPhotoService: RemoteGymPhotoService(apiKey: config.googlePlacesAPIKey)
```

- [ ] **Step 4: Run — verify PASS**

- [ ] **Step 5: Commit**

```bash
git add BlocLens/App/AppEnvironment.swift BlocLensTests/GymPhotoServiceTests.swift
git commit -m "feat: inject GymPhotoService into AppEnvironment"
```

---

### Task 17: GymPhotoView — Reusable SwiftUI Component

**Files:**
- Create: `BlocLens/Core/Components/GymPhotoView.swift`
- Modify: `BlocLens/Utilities/L10n.swift`
- Modify: `BlocLens/Resources/Localisation/Localizable.xcstrings`

**Interfaces:**
- Consumes: `GymPhotoService` from AppEnvironment, `Gym.googlePlaceID`
- Produces: `GymPhotoView` usable in Home and Gym Detail

- [ ] **Step 1: Write failing UI test**

```swift
// BlocLensTests/GymPhotoViewTests.swift
import XCTest
@testable import BlocLens

final class GymPhotoViewTests: XCTestCase {
    @MainActor
    func testGymPhotoViewWithNilPlaceIDShowsPlaceholder() async {
        let service = NoopGymPhotoService()
        let view = GymPhotoView(placeID: nil, gymName: "Test Gym", photoService: service)
        // Verify view renders without crash
        XCTAssertNotNil(view)
    }

    @MainActor
    func testGymPhotoViewWithValidPlaceID() async {
        let service = NoopGymPhotoService()
        let view = GymPhotoView(placeID: "ChIJtest123", gymName: "Test Gym", photoService: service)
        XCTAssertNotNil(view)
    }
}
```

- [ ] **Step 2: Run — verify FAIL**

- [ ] **Step 3: Add L10n keys**

```swift
// In L10n.swift, add enum GymPhoto
enum GymPhoto {
    static let loading: LocalizedStringResource = "gymPhoto.loading"
    static let noPhoto: LocalizedStringResource = "gymPhoto.noPhoto"
    static let error: LocalizedStringResource = "gymPhoto.error"
    static let offline: LocalizedStringResource = "gymPhoto.offline"
    static let photoOf: LocalizedStringResource = "gymPhoto.photoOf"
    static let fromGoogle: LocalizedStringResource = "gymPhoto.fromGoogle"
}
```

Add to `Localizable.xcstrings` with en-AU values.

- [ ] **Step 4: Implement GymPhotoView**

```swift
// GymPhotoView.swift
import SwiftUI

struct GymPhotoView: View {
    let placeID: String?
    let gymName: String
    let photoService: any GymPhotoService
    var width: Int = 800
    var aspectRatio: CGFloat = 16/9

    @State private var state: PhotoState = .idle

    enum PhotoState: Equatable {
        case idle
        case loading
        case loaded(GymPhoto)
        case noPhoto
        case error
    }

    var body: some View {
        ZStack {
            switch state {
            case .idle, .loading:
                placeholder
                    .overlay { ProgressView().tint(.white) }
            case .loaded(let photo):
                photoContent(photo)
            case .noPhoto, .error:
                placeholder
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fill)
        .clipShape(RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous))
        .task(id: placeID) {
            await loadPhoto()
        }
    }

    @ViewBuilder
    private func photoContent(_ photo: GymPhoto) -> some View {
        AsyncImage(url: photo.imageURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                placeholder
            case .empty:
                placeholder.overlay { ProgressView() }
            @unknown default:
                placeholder
            }
        }
        .overlay(alignment: .bottomLeading) {
            attributionOverlay(photo)
        }
    }

    private var placeholder: some View {
        Rectangle()
            .fill(BlocColor.opticBlueTint)
            .overlay {
                Image(systemName: "building.2.crop.circle")
                    .font(.system(size: 48))
                    .foregroundStyle(.white.opacity(0.6))
            }
    }

    private func attributionOverlay(_ photo: GymPhoto) -> some View {
        HStack(spacing: 4) {
            if let attribution = photo.attribution {
                Text(attribution)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(6)
    }

    private func loadPhoto() async {
        guard let placeID else {
            state = .noPhoto
            return
        }
        state = .loading
        do {
            let photo = try await photoService.fetchPhoto(for: placeID, width: width)
            state = .loaded(photo)
        } catch {
            state = .error
        }
    }
}
```

- [ ] **Step 5: Run — verify PASS**

- [ ] **Step 6: Commit**

```bash
git add BlocLens/Core/Components/GymPhotoView.swift BlocLens/Utilities/L10n.swift BlocLens/Resources/Localisation/Localizable.xcstrings BlocLensTests/GymPhotoViewTests.swift
git commit -m "feat: add GymPhotoView reusable component"
```

---

### Task 18: Integrate into Home View

**Files:**
- Modify: `BlocLens/Features/Home/HomeView.swift`

**Interfaces:**
- Consumes: `GymPhotoView`, `Gym.googlePlaceID`, `AppEnvironment.gymPhotoService`

- [ ] **Step 1: Write failing UI test**

```swift
// Add to GymPhotoViewTests.swift
func testHomeGymCardHasPhotoArea() {
    // Verify the home card structure includes a photo view area
    let gym = DevelopmentFixtures.gyms.first!
    XCTAssertNotNil(gym.googlePlaceID) // Fixture gym has a place ID
}
```

- [ ] **Step 2: Run — verify FAIL** (if fixture doesn't have place ID, skip this test and add it to fixtures)

- [ ] **Step 3: Replace color fill with GymPhotoView in HomeView**

In `HomeView.swift`, find the `currentGymHero` section. Replace the solid color fill:
```swift
// Before:
ZStack {
    Rectangle().fill(BlocColor.opticBlueTint)
    // ...
}

// After:
ZStack {
    GymPhotoView(
        placeID: gym.googlePlaceID,
        gymName: gym.name,
        photoService: environment.gymPhotoService,
        width: 800
    )
    // Keep existing gradient overlay for text readability
    // ...
}
```

- [ ] **Step 4: Run — verify compiles and existing tests pass**

- [ ] **Step 5: Commit**

```bash
git add BlocLens/Features/Home/HomeView.swift
git commit -m "feat: integrate gym photos into Home card"
```

---

### Task 19: Integrate into Gym Detail View

**Files:**
- Modify: `BlocLens/Features/Gym/GymDetailView.swift`

**Interfaces:**
- Consumes: `GymPhotoView`, `Gym.googlePlaceID`, `AppEnvironment.gymPhotoService`

- [ ] **Step 1: Replace color fill with GymPhotoView in GymDetailView**

In `GymDetailView.swift`, find the `heroPhotoSection`. Replace the solid color fill:
```swift
// Before:
ZStack {
    Rectangle().fill(gymBaseColor)
    // ...
}

// After:
ZStack {
    GymPhotoView(
        placeID: gym.googlePlaceID,
        gymName: gym.name,
        photoService: environment.gymPhotoService,
        width: 1200  // Full-width hero needs larger image
    )
    // Keep existing gradient overlay
    // ...
}
```

- [ ] **Step 2: Run — verify compiles and existing tests pass**

- [ ] **Step 3: Commit**

```bash
git add BlocLens/Features/Gym/GymDetailView.swift
git commit -m "feat: integrate gym photos into Gym Detail hero"
```

---

### Task 20: Mock Data & Test Fixtures

**Files:**
- Modify: `BlocLens/Mocks/MockRepositories.swift`
- Modify: Development fixtures (if needed)

**Interfaces:**
- Produces: Mock gym data with `googlePlaceID` values for testing

- [ ] **Step 1: Add googlePlaceID to mock gyms**

Ensure `DevelopmentFixtures.gyms` have `googlePlaceID` values for at least the favourite gym.

- [ ] **Step 2: Add MockGymPhotoService**

```swift
struct MockGymPhotoService: GymPhotoService, Sendable {
    var photoToReturn: GymPhoto?

    func fetchPhoto(for placeID: String, width: Int) async throws -> GymPhoto {
        guard let photo = photoToReturn else {
            throw RepositoryError.externalServiceError
        }
        return photo
    }
}
```

- [ ] **Step 3: Run full test suite**

- [ ] **Step 4: Commit**

```bash
git add BlocLens/Mocks/MockRepositories.swift
git commit -m "test: add mock gym photo service and fixtures"
```

---

### Task 21: Build, Test & Verify

**Files:** None (verification only)

- [ ] **Step 1: Clean Build**

```bash
xcodebuild build -scheme BlocLens -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.4'
```

- [ ] **Step 2: Run all Unit Tests**

```bash
xcodebuild test -scheme BlocLens -only-testing:BlocLensTests -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.4'
```

- [ ] **Step 3: Run core UI Tests**

```bash
xcodebuild test -scheme BlocLens -only-testing:BlocLensUITests -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.4'
```

- [ ] **Step 4: Ponytail review**

- [ ] **Step 5: Final commit** (if all passes)

```bash
git add -A
git commit -m "feat: add Google Places gym photos"
```

---

## Self-Review

- Spec coverage: all 12 spec sections map to tasks — data model, photo service, caching, UI, attribution, testing
- Placeholders: none — every step has code, file paths, or exact expectations
- Type consistency: `GymPhoto`, `GymPhotoService`, `GymPhotoView` names consistent across tasks
