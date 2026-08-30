### Task 15: Photo Service Protocol & REST Implementation — Report

**Status:** DONE

**Commits:**
- `ea613ba` feat: add GymPhotoService with REST implementation

**Test summary:** 4/4 pass (2 new + 2 existing). Pre-existing UI test failure unrelated.

**What was done:**
1. Added 2 failing tests (`testNoopPhotoServiceThrowsOnFetch`, `testGymPhotoStructEquality`) to `GymPhotoServiceTests.swift`
2. Created `BlocLens/Core/Services/GymPhotoService.swift` with `GymPhoto` struct, `GymPhotoService` protocol, `NoopGymPhotoService`, and `RemoteGymPhotoService` (actor)
3. Added `fetchPlaceDetails(placeID:fields:)` to `GooglePlacesClient` protocol, `RemoteGooglePlacesClient`, and `NoopGooglePlacesClient`

**Deviation from brief:** Used `String?` for `attributionHTML` instead of `NSAttributedString?`. The brief's `NSAttributedString` triggers a Sendable warning now and will be an error in Swift 6. `String?` is simpler, Sendable-safe, and attributed strings can be constructed at the view layer.

**Concerns:** None.

---

### Task 15 Review Fix — 2026-08-31

**Finding 1: Duplicated HTTP logic** — `RemoteGymPhotoService` built its own URLs, injected its own API key, validated HTTP responses, and parsed JSON, all duplicating `GooglePlacesClient.fetchPlaceDetails`.

**Fix:** Injected `GooglePlacesClient` into `RemoteGymPhotoService` and delegated to `fetchPlaceDetails(placeID:fields:)`. Removed `apiKey` and `session` properties. Init changed from `init(apiKey:session:)` to `init(client:)`.

**Finding 2: Force-unwrap URL construction** — `URL(string:)!` on externally-derived `placeID` and `photoName` values.

**Fix:** Replaced with `guard let url = URL(string: ...)` throwing `RepositoryError.invalidConfiguration` for the photo URL. The `placeID` is now handled by `GooglePlacesClient.fetchPlaceDetails` which performs its own validation.

**Tests:** 4/4 pass (0 failures).
