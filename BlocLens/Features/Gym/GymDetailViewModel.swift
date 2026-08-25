import Combine

@MainActor
final class GymDetailViewModel: ObservableObject {
    @Published private(set) var state: LoadableState<[WallZone]> = .initial

    private let gym: Gym
    private let repository: any GymRepository

    init(gym: Gym, repository: any GymRepository) {
        self.gym = gym
        self.repository = repository
    }

    func load() async {
        state = .loading
        do {
            let zones = try await repository.wallZones(gymID: gym.id)
            state = zones.isEmpty ? .empty : .loaded(zones)
        } catch RepositoryError.offlineNoCache {
            state = .offlineWithoutCache
        } catch let error as RepositoryError {
            state = .error(error)
        } catch {
            state = .error(.fixtureFailure)
        }
    }
}
