import Foundation
import Combine

enum GymPhotoCarouselState: Equatable {
    case idle
    case loading
    case loaded(GymPhoto)
    case error(String)
    case empty
}

@MainActor
final class GymPhotoCarouselViewModel: ObservableObject {
    @Published private(set) var states: [Int: GymPhotoCarouselState] = [:]
    @Published private(set) var availableCount: Int = 0
    @Published var selectedIndex: Int = 0

    let placeID: String?
    let gymName: String
    let loader: any GymPhotoLoader
    let maxPhotos = 4
    private var loadTasks: [Int: Task<Void, Never>] = [:]
    private var preloadTasks: [Int: Task<Void, Never>] = [:]

    init(placeID: String?, gymName: String, loader: any GymPhotoLoader) {
        self.placeID = placeID
        self.gymName = gymName
        self.loader = loader
    }

    var displayCount: Int {
        if placeID == nil { return 0 }
        return availableCount == 0 ? 0 : min(availableCount, maxPhotos)
    }

    var hasContent: Bool { displayCount > 0 }
    var shouldShowIndicator: Bool { displayCount > 1 }

    private var lastWidth: Int = 800

    func initialLoad(width: Int? = nil) async {
        if let w = width { lastWidth = GymPhotoBucket.bucket(for: w) }
        guard let placeID else {
            availableCount = 0
            return
        }
        do {
            let count = try await loader.availablePhotoCount(for: placeID)
            availableCount = min(count, maxPhotos)
            if availableCount == 0 { return }
            await loadIfNeeded(index: 0, width: lastWidth)
        } catch {
            availableCount = 0
        }
    }

    func initialLoad() async { await initialLoad(width: nil) }

    func loadIfNeeded(index: Int, width: Int? = nil) async {
        let w = width.map { GymPhotoBucket.bucket(for: $0) } ?? lastWidth
        if width != nil { lastWidth = w }
        guard let placeID else { return }
        guard index >= 0 && index < maxPhotos else { return }
        if availableCount == 0 {
            do {
                let count = try await loader.availablePhotoCount(for: placeID)
                availableCount = min(count, maxPhotos)
            } catch {
                availableCount = 0
                return
            }
        }
        guard index < availableCount else { return }
        if case .loaded = states[index] { return }
        if case .loading = states[index] { return }
        if let cached = await loader.cachedPhoto(for: placeID, at: index) {
            // If cached is for different bucket, check if we can reuse larger
            states[index] = .loaded(cached)
            return
        }
        states[index] = .loading
        // Cancel previous task for this index if any
        loadTasks[index]?.cancel()
        let task = Task { @MainActor in
            do {
                let photo = try await loader.loadPhoto(for: placeID, at: index, width: w)
                try Task.checkCancellation()
                states[index] = .loaded(photo)
            } catch is CancellationError {
                states[index] = .idle
            } catch {
                if Task.isCancelled {
                    states[index] = .idle
                } else if let repoError = error as? RepositoryError, repoError == .notFound {
                    do {
                        let freshCount = try await loader.refreshPhotoCount(for: placeID)
                        self.availableCount = min(freshCount, self.maxPhotos)
                        if index < freshCount {
                            states[index] = .idle
                            let retryPhoto = try await loader.loadPhoto(for: placeID, at: index, width: w)
                            states[index] = .loaded(retryPhoto)
                            for i in (index+1)..<self.availableCount {
                                if case .error = states[i] { states[i] = .idle }
                            }
                        } else {
                            states[index] = .empty
                        }
                    } catch {
                        states[index] = .error(error.localizedDescription)
                    }
                } else {
                    states[index] = .error(error.localizedDescription)
                }
            }
        }
        loadTasks[index] = task
        await task.value
        loadTasks[index] = nil
        // Preload adjacent only if this was the currently selected page (avoid chain)
        if case .loaded = states[index], index == selectedIndex {
            preloadAdjacent(for: index)
        }
    }

    private func preloadAdjacent(for index: Int) {
        guard availableCount > 1 else { return }
        // Only preload immediate neighbors of the *current* index, not of preloads themselves
        guard index == selectedIndex else { return }
        for adj in [index - 1, index + 1] {
            guard adj >= 0 && adj < availableCount else { continue }
            if case .loaded = states[adj] { continue }
            if case .loading = states[adj] { continue }
            if loadTasks[adj] != nil { continue }
            if preloadTasks[adj] != nil { continue }
            let t = Task(priority: .utility) { @MainActor in
                await self.loadIfNeeded(index: adj)
                self.preloadTasks[adj] = nil
            }
            preloadTasks[adj] = t
        }
    }

    func retry(index: Int) async {
        states[index] = .idle
        await loadIfNeeded(index: index)
    }

    func cancelLoad(at index: Int) {
        loadTasks[index]?.cancel()
        loadTasks[index] = nil
        if case .loading = states[index] {
            states[index] = .idle
        }
    }

    func cancelAll() {
        for (_, task) in loadTasks { task.cancel() }
        loadTasks.removeAll()
        for (_, task) in preloadTasks { task.cancel() }
        preloadTasks.removeAll()
        Task {
            if let loader = loader as? MockGymPhotoLoader {
                await loader.cancelAll()
            } else if let loader = loader as? RemoteGymPhotoLoader {
                await loader.cancelAll()
            }
        }
    }

    func onAppear() async {
        await initialLoad()
    }

    func onDisappear() {
        cancelAll()
    }

    func onSelectedIndexChanged(_ newIndex: Int) async {
        await loadIfNeeded(index: newIndex)
    }
}
