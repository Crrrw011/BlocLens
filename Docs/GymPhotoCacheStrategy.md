# Gym Photo Cache Strategy

## Source & Compliance
- **Source**: Google Places API (New) – `Place Details` + `Place Photos` (`photos.name` → `media?skipHttpRedirect` → `photoUri`).
- **Attribution**: `authorAttributions` retained and displayed where provided (carousel overlay). Not stripped.
- **Caching policy**: Google Maps Platform Terms 3.2.3(b) – *No Caching* except limited temporary performance cache. `place_id` may be stored indefinitely; `lat/lng` up to 30 days; **photo `name` must not be cached** beyond the request and **photo content may be cached temporarily up to 30 days** for performance, secure, not manipulated. Implementation respects this:
  - `photoName` (`places/.../photos/...`) cached only in memory (`GymPhotoCache` actor) and refreshed on next `availablePhotoCount` or on media 404.
  - Image **bytes** cached on disk **max 30 days TTL** (`GymPhotoDiskCache.ttl = 30*24*60*60`). Expired entries deleted on read and during LRU.
  - No API key, token, or full sensitive URL in filename or logs. Key = `SHA256(photoName)` hex.

## Two-Level Cache
```
Memory (GymPhotoCache, NSCache-like Dictionary, actor)
  ↓ miss
Disk (Library/Caches/BlocLens/GymPhotos/<sha256>.jpg)
  ↓ miss or expired/corrupted
Remote (Places Details → media → photoUri → image bytes)
```
- **Read order**: Memory → Disk → Remote. Disk hit does not hit network.
- **Write**: Only after successful download **and** `UIImage(data:) != nil` (reject HTML error, empty, non-image). Atomic write via temp file + move.
- **Concurrency**: `actor` isolation, `inFlight` dictionary merges concurrent identical requests to one network call.
- **Threading**: All disk IO, decoding, size calculation, and deletion off `MainActor` (inside `actor`). ViewModel/Loader never block main.

## Disk Location & Key
- **Path**: `Library/Caches/BlocLens/GymPhotos/` (via `FileManager.cachesDirectory`), not `Documents`. System may purge; app falls back to remote.
- **Key**: `SHA256(photoName)` → `<hex>.jpg`, no query params, no key.
- **Metadata**: file `modificationDate` = last access for LRU; size via `resourceValues`.

## Capacity & LRU
- **Capacity**: `200 MB` (`GymPhotoDiskCache.capacityBytes`). Centralized, not scattered in Views.
- **Eviction**: On write, if `totalSize > capacity`, sort by `modificationDate` ascending and delete oldest until under capacity.
- **TTL**: `30 days` – on read, if `now - modificationDate > ttl`, file deleted and treated as miss.

## Preload
- Current image loads immediately.
- After success, **adjacent** (`prev`/`next`) preloaded with `.utility` priority, deduped by real `photoName`/`index`, cancellable on `onDisappear`/`gym` change.
- At most 2 preloads per gym, no cross-gym, no 1000 virtual duplication.

## Settings
- `Settings → Clear Image Cache` shows real size via `ByteCountFormatter` (file style), async, `0 B` when empty.
- Clear deletes only `BlocLens/GymPhotos` namespace and in-memory cache, not Logbook/Profile/Auth/Onboarding/fixtures. Confirmation dialog when `>0`, progress disables button, error shows real message, success updates to `0 B`. `44pt` touch, VoiceOver label/value/hint.

## Offline & Restart
- Offline: disk hit serves without network; miss shows placeholder/error.
- Restart: new `GymPhotoDiskCache` instance same directory reads same files.
- Corrupted: `UIImage(data:) == nil` or empty → file deleted, reload from remote without crash.

## Auto-Play
- Interval: 4s stable display + `0.72s` `easeInOut` horizontal slide (not crossfade). Indicator updates after arrival.
- Infinite: finite `displayCount*3` buffer (max 12) with seamless recenter (no flash) via `withAnimation(nil)` jump to middle copy.
- Interruptible: drag pauses `autoTask`, resumes 0.5s after end; background/disappear/gym change cancels task.

## Compliance Check Result
- **Allowed**: Temporary disk cache 30 days for performance, with attribution, in `Caches` – **implemented as above**.
- **Not cached**: `photoName` not persisted beyond memory; image bytes not beyond 30 days; no key in logs.
- **If policy tightens to no disk**: fallback to memory-only `NSCache` (already present) without code change.

