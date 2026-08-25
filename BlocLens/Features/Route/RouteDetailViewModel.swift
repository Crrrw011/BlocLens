import Combine
import Foundation

@MainActor
final class RouteDetailViewModel: ObservableObject {
    @Published private(set) var betaState: LoadableState<[BetaLink]> = .initial
    @Published private(set) var brokenLinks: [BetaLink] = []
    @Published private(set) var logbookEntry: LogbookEntry?
    @Published private(set) var wallZone: WallZone?
    @Published private(set) var saveError: RepositoryError?

    private let route: ClimbingRoute
    private let betaRepository: any BetaRepository
    private let logbookRepository: any LogbookRepository
    private let userID: UserID
    private let gymRepository: any GymRepository

    init(route: ClimbingRoute, environment: AppEnvironment) {
        self.route = route
        betaRepository = environment.betaRepository
        logbookRepository = environment.logbookRepository
        gymRepository = environment.gymRepository
        userID = environment.currentUserID
    }

    func load(viewerProfile: UserProfile? = nil) async {
        betaState = .loading
        do {
            async let betaRequest = betaRepository.betaLinks(
                routeID: route.id,
                viewer: viewerProfile.map {
                    BetaViewerProfile(
                        heightCentimetres: $0.heightCentimetres,
                        armSpanCentimetres: $0.armSpanCentimetres
                    )
                }
            )
            async let brokenRequest = betaRepository.brokenBetaLinks(routeID: route.id)
            async let entryRequest = logbookRepository.entry(userID: userID, routeID: route.id)
            async let zonesRequest = gymRepository.allWallZones()
            let (links, broken, entry, zones) = try await (betaRequest, brokenRequest, entryRequest, zonesRequest)
            betaState = links.isEmpty ? .empty : .loaded(links)
            brokenLinks = broken
            logbookEntry = entry
            wallZone = zones.first { $0.id == route.wallZoneID }
        } catch RepositoryError.offlineNoCache {
            betaState = .offlineWithoutCache
        } catch let error as RepositoryError {
            betaState = .error(error)
        } catch {
            betaState = .error(.fixtureFailure)
        }
    }

    @discardableResult
    func save(status: LogbookStatus) async -> LogbookEntry? {
        do {
            let entry = try await logbookRepository.saveStatus(
                userID: userID,
                routeID: route.id,
                status: status,
                date: Date()
            )
            logbookEntry = entry
            saveError = nil
            return entry
        } catch let error as RepositoryError {
            saveError = error
            return nil
        } catch {
            saveError = .fixtureFailure
            return nil
        }
    }

    @discardableResult
    func update(details: LogbookDetails) async -> LogbookEntry? {
        guard let entry = logbookEntry else { return nil }
        do {
            let updated = try await logbookRepository.updateDetails(entryID: entry.id, details: details)
            logbookEntry = updated
            saveError = nil
            return updated
        } catch let error as RepositoryError {
            saveError = error
            return nil
        } catch {
            saveError = .fixtureFailure
            return nil
        }
    }

    func clearSaveError() {
        saveError = nil
    }
}
