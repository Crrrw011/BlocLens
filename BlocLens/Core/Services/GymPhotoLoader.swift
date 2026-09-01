import Foundation
#if canImport(UIKit)
import UIKit
#endif
import ImageIO

nonisolated enum GymPhotoCachePolicy: Sendable, Equatable {
    case memoryOnly
    case diskAllowed(ttl: Duration)
    case noStore
}

nonisolated enum GymPhotoSource: String, Sendable {
    case googlePlaces
    case blocLens
    case authorisedExternal
    case unknown
}

nonisolated struct GymPhotoVariantKey: Hashable, Sendable {
    let sourceID: String // photoName or storage path
    let pixelWidthBucket: Int
}

nonisolated enum GymPhotoBucket {
    static let buckets = [640, 960, 1280, 1600]
    static func bucket(for pixelWidth: Int) -> Int {
        let clamped = min(max(pixelWidth, 320), 2000)
        for b in buckets { if clamped <= b { return b } }
        return buckets.last!
    }
    static func bestFit(for target: Int, available: [Int]) -> Int? {
        if available.contains(target) { return target }
        let larger = available.filter { $0 >= target }.sorted()
        if let first = larger.first { return first }
        return available.sorted().last
    }
}

// MARK: - GymPhotoLoader Abstraction

nonisolated protocol GymPhotoLoader: Sendable {
    func loadPhoto(for placeID: String, at index: Int, width: Int) async throws -> GymPhoto
    func availablePhotoCount(for placeID: String) async throws -> Int
    func cachedPhoto(for placeID: String, at index: Int) async -> GymPhoto?
    func refreshPhotoCount(for placeID: String) async throws -> Int
    func diskCacheSize() async -> Int
    func formattedDiskCacheSize() async -> String
    func clearCache() async throws
    func cachedImage(for photoName: String) async -> UIImage?
}

extension GymPhotoLoader {
    func cachedPhoto(for placeID: String, at index: Int) async -> GymPhoto? { nil }
    func refreshPhotoCount(for placeID: String) async throws -> Int { try await availablePhotoCount(for: placeID) }
    func diskCacheSize() async -> Int { 0 }
    func formattedDiskCacheSize() async -> String {
        let size = await diskCacheSize()
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f.string(fromByteCount: Int64(size))
    }
    func clearCache() async throws {}
    func cachedImage(for photoName: String) async -> UIImage? { nil }
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

    func clearAll() {
        photoNamesByPlaceID.removeAll()
        cachedPhotos.removeAll()
        photoCountCache.removeAll()
        for t in inFlight.values { t.cancel() }
        inFlight.removeAll()
    }
}

// MARK: - Memory Image Cache (decoded, LRU, max 20 images ~4*5 gyms, variant-aware)

actor GymPhotoMemoryImageCache {
    private var cache: [GymPhotoVariantKey: UIImage] = [:]
    private var order: [GymPhotoVariantKey] = []
    private let maxCount = 20
    func image(for variant: GymPhotoVariantKey) -> UIImage? { cache[variant] }
    // Best-fit reuse: exact or larger, else largest smaller
    func bestImage(for variant: GymPhotoVariantKey) -> UIImage? {
        if let exact = cache[variant] { return exact }
        let candidates = cache.keys.filter { $0.sourceID == variant.sourceID }
        if let bestKey = GymPhotoBucket.bestFit(for: variant.pixelWidthBucket, available: candidates.map { $0.pixelWidthBucket }),
           let key = candidates.first(where: { $0.pixelWidthBucket == bestKey }) {
            return cache[key]
        }
        return nil
    }
    func set(_ image: UIImage, for variant: GymPhotoVariantKey) {
        cache[variant] = image
        order.removeAll { $0 == variant }
        order.append(variant)
        while cache.count > maxCount, let oldest = order.first {
            cache.removeValue(forKey: oldest)
            order.removeFirst()
        }
    }
    // Legacy string key for tests
    func image(forKey key: String) -> UIImage? {
        cache.first { $0.key.sourceID == key }?.value
    }
    func set(_ image: UIImage, forKey key: String) {
        let v = GymPhotoVariantKey(sourceID: key, pixelWidthBucket: 1280)
        set(image, for: v)
    }
    func clear() { cache.removeAll(); order.removeAll() }
}

// MARK: - Remote Loader

actor RemoteGymPhotoLoader: GymPhotoLoader {
    private let client: GooglePlacesClient
    private let cache = GymPhotoCache()
    private let diskCache: GymPhotoDiskCache
    private let memoryImageCache = GymPhotoMemoryImageCache()

    init(client: GooglePlacesClient, diskCache: GymPhotoDiskCache? = nil) {
        self.client = client
        self.diskCache = diskCache ?? GymPhotoDiskCache()
        // Clear memory on pressure
        Task { @MainActor in
            NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: nil) { _ in
                Task { await self.memoryImageCache.clear() }
            }
        }
    }

    nonisolated private func policy(for photoName: String) -> GymPhotoCachePolicy {
        if photoName.hasPrefix("places/") { return .memoryOnly }
        return .diskAllowed(ttl: .seconds(30*24*60*60))
    }

    nonisolated private func downsample(data: Data, toPixelWidth: Int) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: toPixelWidth,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let uiImage = UIImage(cgImage: cgImage)
        return uiImage.jpegData(compressionQuality: 0.85) ?? uiImage.pngData()
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
        let bucket = GymPhotoBucket.bucket(for: width)
        // Variant-aware memory hit (exact or larger)
        // We still keep placeID#index cache for quick, but also check variant image cache
        if let cached = await cache.cachedPhoto(placeID: placeID, index: index) {
            // If cached photo's bucket matches or larger, reuse
            if let cachedName = cached.photoName, let img = await memoryImageCache.bestImage(for: GymPhotoVariantKey(sourceID: cachedName, pixelWidthBucket: bucket)) {
                _ = img // keep
                return cached
            } else if cached.photoName == nil {
                return cached
            }
        }
        if let task = await cache.inFlightTask(placeID: placeID, index: index) {
            return try await task.value
        }
        let task = Task<GymPhoto, Error> {
            try Task.checkCancellation()
            var names = try await fetchPhotoNamesIfNeeded(placeID: placeID)
            guard index < names.count else { throw RepositoryError.notFound }
            var photoName = names[index]
            func fetchMedia(_ name: String) async throws -> GymPhoto {
                let policy = policy(for: name)
                let variant = GymPhotoVariantKey(sourceID: name, pixelWidthBucket: bucket)
                if let img = await memoryImageCache.bestImage(for: variant) {
                    _ = img
                    if case .diskAllowed = policy, let _ = await diskCache.data(for: variant) {
                        let fileURL = await diskCache.fileURL(for: variant)
                        let attr = await attributionForPhoto(at: index, placeID: placeID)
                        let photo = GymPhoto(imageURL: fileURL, attribution: attr, attributionHTML: nil, photoName: name, source: .googlePlaces)
                        await cache.storePhoto(photo, placeID: placeID, index: index)
                        return photo
                    } else if case .memoryOnly = policy {
                        let attr = await attributionForPhoto(at: index, placeID: placeID)
                        let photo = GymPhoto(imageURL: URL(string: "memory://\(name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name)")!, attribution: attr, attributionHTML: nil, photoName: name, source: .googlePlaces)
                        await cache.storePhoto(photo, placeID: placeID, index: index)
                        return photo
                    }
                }
                if case .diskAllowed = policy {
                    if let _ = await diskCache.data(for: variant) {
                        let fileURL = await diskCache.fileURL(for: variant)
                        let attr = await attributionForPhoto(at: index, placeID: placeID)
                        let photo = GymPhoto(imageURL: fileURL, attribution: attr, attributionHTML: nil, photoName: name, source: .blocLens)
                        await cache.storePhoto(photo, placeID: placeID, index: index)
                        if let data = await diskCache.data(for: variant), let img = UIImage(data: data) {
                            await memoryImageCache.set(img, for: variant)
                        }
                        return photo
                    }
                } else if case .memoryOnly = policy {
                    // For memoryOnly, check if we have file from previous diskAllowed run (should not happen) – treat as miss
                }
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
                let (imageDataRaw, imageResponse) = try await URLSession.shared.data(from: photoURL)
                try Task.checkCancellation()
                guard let http2 = imageResponse as? HTTPURLResponse, (200..<300).contains(http2.statusCode), !imageDataRaw.isEmpty else {
                    throw RepositoryError.decodingFailure
                }
                let targetBucket = bucket
                let targetData: Data = {
                    if let down = downsample(data: imageDataRaw, toPixelWidth: targetBucket) { return down }
                    return imageDataRaw
                }()
                #if canImport(UIKit)
                guard let uiImage = UIImage(data: targetData) else { throw RepositoryError.decodingFailure }
                let variantForStore = GymPhotoVariantKey(sourceID: name, pixelWidthBucket: targetBucket)
                await memoryImageCache.set(uiImage, for: variantForStore)
                #endif
                if case .diskAllowed = policy {
                    let v = GymPhotoVariantKey(sourceID: name, pixelWidthBucket: targetBucket)
                    await diskCache.store(data: targetData, for: v)
                    let fileURL = await diskCache.fileURL(for: v)
                    let attr = await attributionForPhoto(at: index, placeID: placeID)
                    let photo = GymPhoto(imageURL: fileURL, attribution: attr, attributionHTML: nil, photoName: name, source: .blocLens)
                    await cache.storePhoto(photo, placeID: placeID, index: index)
                    return photo
                } else {
                    let attr = await attributionForPhoto(at: index, placeID: placeID)
                    let photo = GymPhoto(imageURL: photoURL, attribution: attr, attributionHTML: nil, photoName: name, source: .googlePlaces)
                    await cache.storePhoto(photo, placeID: placeID, index: index)
                    return photo
                }
            }
            do {
                return try await fetchMedia(photoName)
            } catch {
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

    func diskCacheSize() async -> Int {
        await diskCache.totalSize()
    }

    func formattedDiskCacheSize() async -> String {
        await diskCache.formattedSize()
    }

    func clearCache() async throws {
        await cache.clearAll()
        await memoryImageCache.clear()
        try await diskCache.clear()
    }

    func cachedImage(for photoName: String) async -> UIImage? {
        // Try exact, then best-fit larger
        if let img = await memoryImageCache.image(forKey: photoName) { return img }
        // Try variant best fit
        let buckets = GymPhotoBucket.buckets
        for b in buckets {
            let v = GymPhotoVariantKey(sourceID: photoName, pixelWidthBucket: b)
            if let img = await memoryImageCache.image(for: v) { return img }
        }
        return nil
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

    func cachedImage(for photoName: String) async -> UIImage? { nil }
}

// MARK: - Shared GymPhotoCache for cross-view reuse (injected via AppEnvironment)

actor SharedGymPhotoCache {
    static let shared = SharedGymPhotoCache()
    private var cache: [String: GymPhoto] = [:]
    func get(placeID: String, index: Int) -> GymPhoto? { cache["\(placeID)#\(index)"] }
    func set(_ photo: GymPhoto, placeID: String, index: Int) { cache["\(placeID)#\(index)"] = photo }
    func clear() { cache.removeAll() }
}
