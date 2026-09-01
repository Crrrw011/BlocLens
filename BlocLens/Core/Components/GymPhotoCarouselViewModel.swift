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

    func initialLoad() async {
        guard let placeID else {
            availableCount = 0
            return
        }
        do {
            let count = try await loader.availablePhotoCount(for: placeID)
            availableCount = min(count, maxPhotos)
            if availableCount == 0 {
                // Empty state handled by view
                return
            }
            // Only load first image initially
            await loadIfNeeded(index: 0)
        } catch {
            availableCount = 0
        }
    }

    func loadIfNeeded(index: Int) async {
        guard let placeID else { return }
        guard index >= 0 && index < maxPhotos else { return }
        // Lazy initialise availableCount if not yet loaded
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
        // Return if already loaded or loading
        if case .loaded = states[index] { return }
        if case .loading = states[index] { return }
        // Check cache synchronously
        if let cached = await loader.cachedPhoto(for: placeID, at: index) {
            states[index] = .loaded(cached)
            return
        }
        states[index] = .loading
        // Cancel previous task for this index if any
        loadTasks[index]?.cancel()
        let task = Task { @MainActor in
            do {
                let photo = try await loader.loadPhoto(for: placeID, at: index, width: 800)
                try Task.checkCancellation()
                states[index] = .loaded(photo)
            } catch is CancellationError {
                states[index] = .idle
            } catch {
                if Task.isCancelled {
                    states[index] = .idle
                } else if let repoError = error as? RepositoryError, repoError == .notFound {
                    // Auto-refill: photo at this index was deleted, refresh count and retry once
                    do {
                        let freshCount = try await loader.refreshPhotoCount(for: placeID)
                        self.availableCount = min(freshCount, self.maxPhotos)
                        if index < freshCount {
                            states[index] = .idle
                            let retryPhoto = try await loader.loadPhoto(for: placeID, at: index, width: 800)
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
