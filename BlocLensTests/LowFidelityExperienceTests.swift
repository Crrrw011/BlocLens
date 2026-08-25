import Foundation
import Testing
@testable import BlocLens

@MainActor
struct LowFidelityExperienceTests {
    @Test func onboardingCompletionPersistsInInjectedStore() async {
        let store = InMemoryOnboardingStore(isComplete: false)
        let environment = AppEnvironment.development(onboardingStore: store)
        let session = AppSession(environment: environment)

        await session.load()
        #expect(!session.hasCompletedOnboarding)
        session.completeOnboarding()
        #expect(store.isComplete())
        #expect(session.selectedTab == .map)
    }

    @Test func mockAuthenticationGateRestoresOriginalIntent() async {
        let environment = AppEnvironment.development(authenticationState: .guest)
        let session = AppSession(environment: environment)
        await session.load()
        let intent = ProtectedIntent.revealBeta(routeID: "west-end-slab-r1")

        #expect(!session.requireAuthentication(for: intent))
        #expect(session.pendingIntent == intent)
        await session.signInWithMockAccount()

        #expect(session.authenticationState.profile?.username == "Alex")
        #expect(session.resumedIntent == intent)
        #expect(!session.isSignInGatePresented)
    }

    @Test func mapFacilityFiltersRequireEverySelectedFacility() {
        let result = GymFilterService.filter(
            DevelopmentFixtures.gyms,
            options: GymFilterOptions(facilities: [.showers, .cafe]),
            referenceDate: Date(timeIntervalSince1970: 1_780_000_000),
            mockOpenGymIDs: []
        )
        #expect(!result.isEmpty)
        #expect(result.allSatisfy { $0.facilities.contains(.showers) && $0.facilities.contains(.cafe) })
    }

    @Test func mapHasBetaFilterExcludesGymsWithoutBeta() {
        let result = GymFilterService.filter(
            DevelopmentFixtures.gyms,
            options: GymFilterOptions(hasBeta: true),
            referenceDate: Date(timeIntervalSince1970: 1_780_000_000),
            mockOpenGymIDs: []
        )
        #expect(result.allSatisfy { $0.betaCount > 0 })
    }

    @Test func routeSortingUsesRequestedDeterministicOrder() {
        let routes = DevelopmentFixtures.routes.filter { $0.wallZoneID == "west-end-slab" }
        let byBeta = RouteListPresentation.currentRoutes(
            routes,
            options: RouteListOptions(sort: .mostBeta)
        )
        #expect(byBeta == byBeta.sorted {
            $0.betaCount == $1.betaCount ? $0.id.rawValue < $1.id.rawValue : $0.betaCount > $1.betaCount
        })
    }

    @Test func archivedRoutesRemainIsolatedFromCurrentRoutes() {
        let current = RouteListPresentation.currentRoutes(DevelopmentFixtures.routes, options: RouteListOptions())
        let archived = RouteListPresentation.archivedRoutes(DevelopmentFixtures.routes, options: RouteListOptions())
        #expect(current.allSatisfy { $0.lifecycle == .active })
        #expect(archived.allSatisfy { $0.lifecycle == .archived })
        #expect(Set(current.map(\.id)).isDisjoint(with: Set(archived.map(\.id))))
    }

    @Test func contributionPromptDismissalIsSessionScoped() async {
        let environment = AppEnvironment.development()
        let session = AppSession(environment: environment)
        await session.load()
        #expect(session.isContributionPromptVisible("route-photo"))
        session.dismissContributionPrompt("route-photo")
        #expect(!session.isContributionPromptVisible("route-photo"))
    }

    @Test func betaSafetyConfirmationCanBeResetForDevelopment() async {
        let environment = AppEnvironment.development()
        let session = AppSession(environment: environment)
        await session.load()
        session.hasAcknowledgedRevealSafety = true
        session.resetBetaSafetyConfirmation()
        #expect(!session.hasAcknowledgedRevealSafety)
    }
}
