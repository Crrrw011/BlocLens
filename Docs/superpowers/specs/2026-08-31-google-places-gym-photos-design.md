# Google Places Gym Photo Pipeline — Design Spec

**Date:** 2026-08-31
**Task:** Phase 9-B1
**Status:** Approved

## 1. Goal

Display Google-sourced gym photos in BlocLens on:
- Gym Detail page hero section
- Home page favourite/regular gym card

Photos come from Google Places data via REST API. No Google SDK dependency.

## 2. Approach: Google Places REST API (no SDK)

### Why REST over SDK
- Project already has `GooglePlacesClient` REST pattern
- Avoids ~10-15MB Google SDK binary
- Aligns with AGENTS.md "prefer Apple platform frameworks"
- Place ID is only stored (compliant with Google caching policy)
- `URLCache` handles photo caching automatically
- Attribution metadata from Place Details API response

### API Endpoints Used
1. **Place Details** — `GET /v1/places/{place_id}?fields=photos` with header `X-Goog-FieldMask: photos.name,photos.authorAttributions`
2. **Place Photo** — `GET /v1/places/{photo_name}/media?maxWidthPx={width}` → redirects to image URL

### Request Count
- Home card: 1 gym visible → 2 requests (details + photo)
- Gym Detail: 1 gym → 2 requests
- Tab switching: cached by URLCache, no new requests
- Total per session initial load: ~2-4 requests for favourite gym

## 3. Data Model

### Gym Domain Model
```swift
// Add to Gym struct
let googlePlaceID: String?
```

### GymRecord (Supabase mapping)
```swift
// Add to GymRecord
let googlePlaceID: String?
// CodingKey: "google_place_id"
```

No Supabase migration needed — `google_place_id` column already exists in `gyms` table (migration 0003). The field just needs to be decoded.

## 4. Photo Service Architecture

### Protocol (domain layer)
```swift
nonisolated protocol GymPhotoService: Sendable {
    func fetchPhoto(for placeID: String, width: Int) async throws -> GymPhoto
}

nonisolated struct GymPhoto: Equatable, Sendable {
    let imageURL: URL
    let attribution: String?
    let attributionHTML: NSAttributedString?
}
```

### REST Implementation
```swift
actor RemoteGymPhotoService: GymPhotoService {
    let apiKey: String
    
    func fetchPhoto(for placeID: String, width: Int) async throws -> GymPhoto {
        // 1. GET /v1/places/{place_id}?fields=photos
        // 2. Extract first photo name + attribution
        // 3. GET /v1/places/{photo_name}/media?maxWidthPx={width}
        // 4. Return final image URL + attribution
    }
}
```

### Noop Implementation (for dev/test)
```swift
struct NoopGymPhotoService: GymPhotoService {
    func fetchPhoto(for placeID: String, width: Int) async throws -> GymPhoto {
        throw RepositoryError.invalidConfiguration
    }
}
```

### Injection
Added to `AppEnvironment`:
```swift
let gymPhotoService: any GymPhotoService
```

Factory methods:
- `.development(...)` → `NoopGymPhotoService`
- `.localSupabase(...)` → `RemoteGymPhotoService(apiKey:)`
- `.cloudSupabase(...)` → `RemoteGymPhotoService(apiKey:)`

## 5. Caching

- **Mechanism:** Foundation `URLCache` (shared)
- **Capacity:** System default (~4MB memory, ~50MB disk)
- **Behavior:** Best effort — hit = fast, miss = re-fetch, system cleanup = normal
- **No custom cache directory, no Core Data, no UserDefaults image storage**
- **No photo reference/name persistence** — always re-resolve via Place Details
- **Offline with cache:** Show cached image
- **Offline without cache:** Show placeholder

## 6. Data NOT Saved

Per Google caching restrictions, only Place ID is stored:
- ❌ Photo binary data / UIImage
- ❌ Photo download URL (ephemeral)
- ❌ Photo name / reference
- ❌ Author avatars or profiles
- ❌ Attribution HTML
- ❌ Temporary photo metadata
- ❌ Cache file paths

## 7. UI Component: GymPhotoView

### States
| State | Display |
|-------|---------|
| Loading | Skeleton/progress overlay |
| Loaded | Photo with attribution below |
| No Place ID | Placeholder (gym icon) |
| No Photo | Placeholder |
| Error | Placeholder with subtle error indicator |
| Offline + cache | Cached photo |
| Offline no cache | Placeholder |
| Missing attribution | Photo without author line |
| Invalid API config | Placeholder (no crash) |

### Home Card Integration
- Photo fills top portion of card with fixed aspect ratio (16:9 or similar)
- Gym name and info below photo
- Attribution at bottom of photo area
- Card still tappable to Gym Detail

### Gym Detail Hero Integration
- Photo fills full width with stable aspect ratio
- Gradient overlay for text readability (does NOT cover attribution)
- Gym name, verified badge, suburb/state below
- Attribution at bottom edge of photo area, not obscured

### Attribution Display
- Google Maps text attribution always shown with Google photos
- Author attribution shown when provided by Google
- Not hidden by gradients, rounded corners, Safe Area, or overlays
- Dynamic Type: truncation allowed but not complete hiding
- VoiceOver: "Photo of {gym name}, from Google Maps"

## 8. API Key & Security

- API key read from `Info.plist` "GooglePlacesAPIKey" (existing pattern)
- Key must be restricted in Google Cloud Console:
  - iOS Application with correct Bundle Identifier
  - Only Places API (New) enabled
- Release build without valid key → feature disabled (NoopGymPhotoService), no crash
- No secrets in source code beyond Info.plist (existing pattern)

## 9. Google Compliance

### Attribution Requirements
- Google Maps text attribution displayed with all Google photos
- Author attribution displayed when provided
- Attribution not obscured or modified
- Google content visually distinguished from BlocLens content

### Caching Restrictions
- Only Place ID stored (exempt from caching restrictions)
- No photo URLs, references, or metadata persisted
- System-managed URLCache only

### Terms of Service
- Photos used for display purpose only
- No redistribution or modification
- No scraping or unofficial endpoints

## 10. Testing Strategy

### Unit Tests (no real Google network)
1. Gym with Place ID → enters loadable state
2. Gym without Place ID → no request made
3. Loading → Loaded with photo URL
4. Loading → No Photo
5. Loading → Error
6. Task cancellation doesn't write old photo to new gym state
7. Fast gym switching doesn't cause photo cross-contamination
8. Same page lifecycle doesn't re-fetch
9. Place ID doesn't replace BlocLens Gym ID
10. Domain layer doesn't depend on Google SDK or UIImage
11. No custom photo file persistence
12. Home and Gym Detail use consistent data source

### UI Tests (deterministic fake)
1. Home favourite gym shows test photo placeholder
2. Tap Home card → correct Gym Detail
3. Gym Detail hero loading state doesn't jump
4. No photo → placeholder shown
5. Error state doesn't break rest of Gym Detail
6. Offline no cache → understandable state
7. Light Mode
8. Dark Mode
9. Small iPhone
10. Large Dynamic Type
11. Attribution area visible
12. VoiceOver label includes gym name + Google source

## 11. Known Limitations

- Google may change photo ordering without notice
- Some gyms may not have Google photos
- Photo quality varies (user-contributed vs professional)
- No offline-first photo guarantee
- Attribution must be displayed even in compact layouts
- Google Places API has usage quotas and billing

## 12. File Changes

| File | Action | Description |
|------|--------|-------------|
| `Gym.swift` | Modify | Add `googlePlaceID: String?` |
| `GymRecords.swift` | Modify | Decode `google_place_id` |
| `GooglePlacesClient.swift` | Modify | Add `fetchPlacePhotos(placeID:)` |
| `GymPhotoService.swift` | Create | Protocol + REST + Noop implementations |
| `GymPhotoView.swift` | Create | Reusable SwiftUI component |
| `HomeView.swift` | Modify | Replace color fill with GymPhotoView |
| `GymDetailView.swift` | Modify | Replace color fill with GymPhotoView |
| `AppEnvironment.swift` | Modify | Inject GymPhotoService |
| `MockRepositories.swift` | Modify | Add mock photo service |
| `L10n.swift` | Modify | Add photo-related keys |
| `Localizable.xcstrings` | Modify | Add photo strings |
| `GymPhotoServiceTests.swift` | Create | Unit tests |
| `GymPhotoViewTests.swift` | Create | UI tests |
