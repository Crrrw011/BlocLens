import Combine
import SwiftUI

struct AppEnvironment: Sendable {
    let gymRepository: any GymRepository
    let routeRepository: any RouteRepository
    let betaRepository: any BetaRepository
    let logbookRepository: any LogbookRepository
    let currentUserID: UserID
    let scenario: MockRepositoryScenario

    static func development(
        scenario: MockRepositoryScenario = .loaded,
        isOnline: Bool = true
    ) -> AppEnvironment {
        AppEnvironment(
            gymRepository: MockGymRepository(scenario: scenario),
            routeRepository: MockRouteRepository(scenario: scenario),
            betaRepository: MockBetaRepository(scenario: scenario),
            logbookRepository: MockLogbookRepository(isOnline: isOnline),
            currentUserID: DevelopmentFixtures.currentUserID,
            scenario: scenario
        )
    }
}

@MainActor
final class AppSession: ObservableObject {
    @Published var hasAcknowledgedRevealSafety = false
}
