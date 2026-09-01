import Foundation

// MARK: - GymPhotoLoader Abstraction

nonisolated protocol GymPhotoLoader: Sendable {
    func loadPhoto(for placeID: String, at index: Int, width: Int) async throws -> GymPhoto
    func availablePhotoCount(for placeID: String) async throws -> Int
    func cachedPhoto(for placeID: String, at index: Int) async -> GymPhoto?
    func refreshPhotoCount(for placeID: String) async throws -> Int
}

extension GymPhotoLoader {
    func cachedPhoto(for placeID: String, at index: Int) async -> GymPhoto? { nil }
    func refreshPhotoCount(for placeID: String) async throws -> Int { try await availablePhotoCount(for: placeID) }
}

// MARK: - Cache Actor

actor GymPhotoCache {
    private var photoNamesByPlaceID: [String: [String]] = [:]
    private var cachedPhotos: [String: GymPhoto] = [:]
    private var inFlight: [String: Task<GymPhoto, Error>] = [:]
    private var photoCountCache: [String: Int] = [:]

    private func key(placeID: String, index: Int) -> String { "\(placeID)#\(index)" }

    func cachedPhoto(placeID: String, index: Int) -> GymPhoto? {
        cachedPhotos[key(placeID: placeID, index: index)]
    }

    func storePhoto(_ photo: GymPhoto, placeID: String, index: Int) {
        cachedPhotos[key(placeID: placeID, index: index)] = photo
    }

    func storePhotoNames(_ names: [String], placeID: String) {
        let old = photoNamesByPlaceID[placeID]
        photoNamesByPlaceID[placeID] = names
        photoCountCache[placeID] = min(names.count, 4)
        // Auto-compact: if photo list changed (e.g. one deleted, new one appended to keep 4),
        // invalidate cached GymPhotos whose index no longer maps to same name.
        if let old, old != names {
            for i in 0..<4 {
                let k = key(placeID: placeID, index: i)
                if i >= names.count {
                    cachedPhotos.removeValue(forKey: k)
                } else if i < old.count, i < names.count, old[i] != names[i] {
                    // Shift invalidates all from changed index onward
                    for j in i..<4 { cachedPhotos.removeValue(forKey: key(placeID: placeID, index: j)) }
                    break
                }
            }
        }
    }

    func photoNames(placeID: String) -> [String]? {
        photoNamesByPlaceID[placeID]
    }

    func photoCount(placeID: String) -> Int? {
        photoCountCache[placeID]
    }

    func invalidatePhotoNames(placeID: String) {
        photoNamesByPlaceID.removeValue(forKey: placeID)
        photoCountCache.removeValue(forKey: placeID)
        // Clear cached photos for this place so next load re-maps indices
        for i in 0..<4 { cachedPhotos.removeValue(forKey: key(placeID: placeID, index: i)) }
    }

    func inFlightTask(placeID: String, index: Int) -> Task<GymPhoto, Error>? {
        inFlight[key(placeID: placeID, index: index)]
    }

    func setInFlight(_ task: Task<GymPhoto, Error>, placeID: String, index: Int) {
        inFlight[key(placeID: placeID, index: index)] = task
    }

    func removeInFlight(placeID: String, index: Int) {
        inFlight.removeValue(forKey: key(placeID: placeID, index: index))
    }

    func cancelAll() {
        for task in inFlight.values { task.cancel() }
        inFlight.removeAll()
    }

    func cancel(placeID: String, index: Int) {
        let k = key(placeID: placeID, index: index)
        inFlight[k]?.cancel()
        inFlight.removeValue(forKey: k)
    }
}

// MARK: - Remote Loader

actor RemoteGymPhotoLoader: GymPhotoLoader {
    private let client: GooglePlacesClient
    private let cache = GymPhotoCache()

    init(client: GooglePlacesClient) {
        self.client = client
    }

    func availablePhotoCount(for placeID: String) async throws -> Int {
        // Always refresh when called after a deletion; cache is used only for fast path.
        // To keep 4 when one of the first 4 is deleted but a 5th exists, we fetch fresh.
        // We keep cached for performance but allow explicit invalidation.
        if let cached = await cache.photoCount(placeID: placeID) { return cached }
        let names = try await fetchPhotoNames(placeID: placeID)
        await cache.storePhotoNames(names, placeID: placeID)
        return min(names.count, 4)
    }

    func refreshPhotoCount(for placeID: String) async throws -> Int {
        await cache.invalidatePhotoNames(placeID: placeID)
        let names = try await fetchPhotoNames(placeID: placeID)
        await cache.storePhotoNames(names, placeID: placeID)
        return min(names.count, 4)
    }

    func loadPhoto(for placeID: String, at index: Int, width: Int) async throws -> GymPhoto {
        if index < 0 || index >= 4 { throw RepositoryError.invalidInput }
        if let cached = await cache.cachedPhoto(placeID: placeID, index: index) { return cached }
        if let task = await cache.inFlightTask(placeID: placeID, index: index) {
            return try await task.value
        }
        let task = Task<GymPhoto, Error> {
            try Task.checkCancellation()
            var names = try await fetchPhotoNamesIfNeeded(placeID: placeID)
            guard index < names.count else { throw RepositoryError.notFound }
            var photoName = names[index]
            // Fetch media with one retry on invalidation (handles deletion of one of the 4)
            func fetchMedia(_ name: String) async throws -> GymPhoto {
                var mediaComponents = URLComponents(string: "https://places.googleapis.com/v1/\(name)/media")
                mediaComponents?.queryItems = [
                    URLQueryItem(name: "maxWidthPx", value: "\(width)"),
                    URLQueryItem(name: "skipHttpRedirect", value: "true")
                ]
                guard let mediaURL = mediaComponents?.url else { throw RepositoryError.invalidConfiguration }
                var mediaRequest = URLRequest(url: mediaURL)
                mediaRequest.setValue(client.apiKeyForMediaURL, forHTTPHeaderField: "X-Goog-Api-Key")
                if let bundleID = Bundle.main.bundleIdentifier {
                    mediaRequest.setValue(bundleID, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
                }
                let (mediaData, mediaResponse) = try await URLSession.shared.data(for: mediaRequest)
                try Task.checkCancellation()
                guard let http = mediaResponse as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                      let mediaJson = try JSONSerialization.jsonObject(with: mediaData) as? [String: Any],
                      let photoUri = mediaJson["photoUri"] as? String,
                      let photoURL = URL(string: photoUri) else {
                    throw RepositoryError.decodingFailure
                }
                let attribution = await attributionForPhoto(at: index, placeID: placeID)
                let photo = GymPhoto(imageURL: photoURL, attribution: attribution, attributionHTML: nil)
                await cache.storePhoto(photo, placeID: placeID, index: index)
                return photo
            }
            do {
                return try await fetchMedia(photoName)
            } catch {
                // Stale place_id or deleted photo among first 4 -> refresh names and retry once to auto-refill to 4
                // This covers "user deletes one of the 4, new one auto补全"
                await cache.invalidatePhotoNames(placeID: placeID)
                names = try await fetchPhotoNames(placeID: placeID)
                await cache.storePhotoNames(names, placeID: placeID)
                guard index < names.count else { throw RepositoryError.notFound }
                photoName = names[index]
                return try await fetchMedia(photoName)
            }
        }
        await cache.setInFlight(task, placeID: placeID, index: index)
        do {
            let result = try await task.value
            await cache.removeInFlight(placeID: placeID, index: index)
            return result
        } catch {
            await cache.removeInFlight(placeID: placeID, index: index)
            throw error
        }
    }

    func cachedPhoto(for placeID: String, at index: Int) async -> GymPhoto? {
        await cache.cachedPhoto(placeID: placeID, index: index)
    }

    func cancelLoad(for placeID: String, at index: Int) async {
        await cache.cancel(placeID: placeID, index: index)
    }

    func cancelAll() async {
        await cache.cancelAll()
    }

    private func fetchPhotoNamesIfNeeded(placeID: String) async throws -> [String] {
        if let cached = await cache.photoNames(placeID: placeID) { return cached }
        let names = try await fetchPhotoNames(placeID: placeID)
        await cache.storePhotoNames(names, placeID: placeID)
        return names
    }

    private func fetchPhotoNames(placeID: String) async throws -> [String] {
        let json = try await client.fetchPlaceDetails(placeID: placeID, fields: "photos.name,photos.authorAttributions")
        guard let photos = json["photos"] as? [[String: Any]] else { return [] }
        return photos.compactMap { $0["name"] as? String }
    }

    private func attributionForPhoto(at index: Int, placeID: String) async -> String? {
        // We don't have per-photo attribution cached separately; return nil for now.
        // Future: store attributions alongside names.
        nil
    }
}

// MARK: - Mock Loader for Tests/Previews

actor MockGymPhotoLoader: GymPhotoLoader {
    var photosByPlaceID: [String: [GymPhoto]]
    var shouldFailIndices: Set<String> = []
    var requestCounts: [String: Int] = [:]
    var inFlightTasks: [String: Task<GymPhoto, Error>] = [:]
    private var cached: [String: GymPhoto] = [:]
    var delayNanoseconds: UInt64 = 0

    init(photosByPlaceID: [String: [GymPhoto]] = [:], delayNanoseconds: UInt64 = 0) {
        self.photosByPlaceID = photosByPlaceID
        self.delayNanoseconds = delayNanoseconds
    }

    func setPhotos(_ photos: [GymPhoto], for placeID: String) {
        photosByPlaceID[placeID] = Array(photos.prefix(4))
    }

    func setShouldFail(_ shouldFail: Bool, placeID: String, index: Int) {
        let key = "\(placeID)#\(index)"
        if shouldFail { shouldFailIndices.insert(key) } else { shouldFailIndices.remove(key) }
    }

    func requestCount(for placeID: String, index: Int) -> Int {
        requestCounts["\(placeID)#\(index)", default: 0]
    }

    func totalRequestCount(for placeID: String) -> Int {
        requestCounts.filter { $0.key.hasPrefix("\(placeID)#") }.values.reduce(0, +)
    }

    func availablePhotoCount(for placeID: String) async throws -> Int {
        min(photosByPlaceID[placeID]?.count ?? 0, 4)
    }

    func loadPhoto(for placeID: String, at index: Int, width: Int) async throws -> GymPhoto {
        let key = "\(placeID)#\(index)"
        // Return cached if exists
        if let cachedPhoto = cached[key] { return cachedPhoto }
        // Deduplicate in-flight
        if let existing = inFlightTasks[key] {
            return try await existing.value
        }
        // Create task that respects deduplication and cancellation
        let task = Task<GymPhoto, Error> {
            // Record request once per actual network-like fetch
            // We increment count here inside task to allow dedup before execution
            if delayNanoseconds > 0 {
                try await Task.sleep(nanoseconds: delayNanoseconds)
            }
            try Task.checkCancellation()
            if shouldFailIndices.contains(key) {
                throw RepositoryError.network
            }
            guard let photos = photosByPlaceID[placeID], index < photos.count, index < 4 else {
                throw RepositoryError.notFound
            }
            let photo = photos[index]
            return photo
        }
        // Increment request count upfront for deduplication visibility
        // Only count if not already in-flight (we already checked)
        requestCounts[key, default: 0] += 1
        inFlightTasks[key] = task
        do {
            let result = try await task.value
            cached[key] = result
            inFlightTasks.removeValue(forKey: key)
            return result
        } catch {
            inFlightTasks.removeValue(forKey: key)
            // Don't cache failures
            throw error
        }
    }

    func cachedPhoto(for placeID: String, at index: Int) async -> GymPhoto? {
        cached["\(placeID)#\(index)"]
    }

    func cancelLoad(for placeID: String, at index: Int) async {
        let key = "\(placeID)#\(index)"
        inFlightTasks[key]?.cancel()
        inFlightTasks.removeValue(forKey: key)
    }

    func cancelAll() async {
        for task in inFlightTasks.values { task.cancel() }
        inFlightTasks.removeAll()
    }

    func resetCounts() {
        requestCounts.removeAll()
    }
}

// MARK: - Shared GymPhotoCache for cross-view reuse (injected via AppEnvironment)

actor SharedGymPhotoCache {
    static let shared = SharedGymPhotoCache()
    private var cache: [String: GymPhoto] = [:]
    func get(placeID: String, index: Int) -> GymPhoto? { cache["\(placeID)#\(index)"] }
    func set(_ photo: GymPhoto, placeID: String, index: Int) { cache["\(placeID)#\(index)"] = photo }
    func clear() { cache.removeAll() }
}
