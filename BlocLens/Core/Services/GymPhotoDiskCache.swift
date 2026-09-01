import Foundation
import CryptoKit
#if canImport(UIKit)
import UIKit
#endif

/// Disk cache for gym photos: Library/Caches/BlocLens/GymPhotos
/// - Key: SHA256(photoName) hex, no API key/sensitive URL in filename
/// - TTL: 30 days (Google Places temporary caching limit)
/// - Capacity: 200 MB LRU
/// - Thread-safe via actor, disk IO off MainActor
actor GymPhotoDiskCache {
    static let capacityBytes: Int = 200 * 1024 * 1024 // 200 MB
    static let ttl: TimeInterval = 30 * 24 * 60 * 60 // 30 days

    private let directory: URL
    private let fileManager = FileManager.default

    init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            self.directory = caches.appendingPathComponent("BlocLens/GymPhotos", isDirectory: true)
        }
        // Create directory synchronously in init (actor init is sync)
        try? fileManager.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }

    // MARK: - Key
    nonisolated static func key(for photoName: String) -> String {
        let data = Data(photoName.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    func fileURL(forKey key: String) -> URL {
        directory.appendingPathComponent(key).appendingPathExtension("jpg")
    }

    func fileURL(forPhotoName name: String) -> URL {
        fileURL(forKey: Self.key(for: name))
    }

    // Variant-aware
    static func key(for variant: GymPhotoVariantKey) -> String {
        Self.key(for: "\(variant.sourceID)#\(variant.pixelWidthBucket)")
    }
    func fileURL(for variant: GymPhotoVariantKey) -> URL {
        fileURL(forKey: Self.key(for: variant))
    }
    func data(for variant: GymPhotoVariantKey) async -> Data? {
        let url = fileURL(for: variant)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        if let attrs = try? fileManager.attributesOfItem(atPath: url.path),
           let mod = attrs[.modificationDate] as? Date,
           Date().timeIntervalSince(mod) > Self.ttl {
            try? fileManager.removeItem(at: url)
            return nil
        }
        guard let data = try? Data(contentsOf: url), !data.isEmpty else {
            try? fileManager.removeItem(at: url)
            return nil
        }
        #if canImport(UIKit)
        if UIImage(data: data) == nil {
            try? fileManager.removeItem(at: url)
            return nil
        }
        #endif
        try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
        return data
    }
    func store(data: Data, for variant: GymPhotoVariantKey) async {
        guard !data.isEmpty else { return }
        #if canImport(UIKit)
        guard UIImage(data: data) != nil else { return }
        #endif
        let url = fileURL(for: variant)
        let tmp = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension("tmp")
        do {
            try data.write(to: tmp, options: .atomic)
            if fileManager.fileExists(atPath: url.path) { try fileManager.removeItem(at: url) }
            try fileManager.moveItem(at: tmp, to: url)
            try fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
            await evictIfNeeded()
        } catch { try? fileManager.removeItem(at: tmp) }
    }

    // MARK: - Read
    func data(forPhotoName name: String) async -> Data? {
        let url = fileURL(forPhotoName: name)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        // Check TTL
        if let attrs = try? fileManager.attributesOfItem(atPath: url.path),
           let mod = attrs[.modificationDate] as? Date,
           Date().timeIntervalSince(mod) > Self.ttl {
            try? fileManager.removeItem(at: url)
            return nil
        }
        // Check file not corrupted (try decode)
        guard let data = try? Data(contentsOf: url), !data.isEmpty else {
            try? fileManager.removeItem(at: url)
            return nil
        }
        // Validate image can be decoded (avoid caching HTML error)
        #if canImport(UIKit)
        if UIImage(data: data) == nil {
            try? fileManager.removeItem(at: url)
            return nil
        }
        #endif
        // Update access time for LRU
        let now = Date()
        try? fileManager.setAttributes([.modificationDate: now], ofItemAtPath: url.path)
        return data
    }

    func exists(forPhotoName name: String) async -> Bool {
        let url = fileURL(forPhotoName: name)
        guard fileManager.fileExists(atPath: url.path) else { return false }
        if let attrs = try? fileManager.attributesOfItem(atPath: url.path),
           let mod = attrs[.modificationDate] as? Date,
           Date().timeIntervalSince(mod) > Self.ttl {
            try? fileManager.removeItem(at: url)
            return false
        }
        return true
    }

    // MARK: - Write (atomic, validates image, LRU evict)
    func store(data: Data, forPhotoName name: String) async {
        guard !data.isEmpty else { return }
        #if canImport(UIKit)
        guard UIImage(data: data) != nil else { return }
        #endif
        let url = fileURL(forPhotoName: name)
        let temp = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension("tmp")
        do {
            try data.write(to: temp, options: .atomic)
            // Atomic move
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
            try fileManager.moveItem(at: temp, to: url)
            // Update mod date
            try fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
            await evictIfNeeded()
        } catch {
            try? fileManager.removeItem(at: temp)
        }
    }

    // MARK: - Size
    func totalSize() async -> Int {
        guard let urls = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey], options: .skipsHiddenFiles) else { return 0 }
        var total = 0
        for url in urls {
            if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += size
            }
        }
        return total
    }

    func formattedSize() async -> String {
        let size = await totalSize()
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        return formatter.string(fromByteCount: Int64(size))
    }

    // MARK: - LRU Evict
    private func evictIfNeeded() async {
        var total = await totalSize()
        guard total > Self.capacityBytes else { return }
        guard let urls = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey], options: .skipsHiddenFiles) else { return }
        // Sort by mod date ascending (oldest first)
        let sorted = urls.sorted { a, b in
            let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
            let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
            return da < db
        }
        for url in sorted {
            if total <= Self.capacityBytes { break }
            if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                try? fileManager.removeItem(at: url)
                total -= size
            }
        }
    }

    // MARK: - Clear
    func clear() async throws {
        guard fileManager.fileExists(atPath: directory.path) else { return }
        let urls = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
        for url in urls {
            try fileManager.removeItem(at: url)
        }
    }

    func fileCount() async -> Int {
        (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles).count) ?? 0
    }

    // For testing: direct access to directory
    func directoryURL() -> URL { directory }
}
