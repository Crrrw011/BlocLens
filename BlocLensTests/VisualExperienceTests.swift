import SwiftUI
import Testing
@testable import BlocLens

@MainActor
struct VisualExperienceTests {
    @Test func appearanceSelectionMapsToTheRequestedColourScheme() async {
        let environment = AppEnvironment.development()
        let session = AppSession(environment: environment)
        await session.load()

        session.appearancePreference = .system
        #expect(session.preferredColorScheme == nil)
        session.appearancePreference = .light
        #expect(session.preferredColorScheme == .light)
        session.appearancePreference = .dark
        #expect(session.preferredColorScheme == .dark)
    }

    @Test func languageSelectionUpdatesLocaleAndPersistsInInjectedStore() async {
        let store = InMemoryLanguagePreferenceStore()
        let environment = AppEnvironment.development(languagePreferenceStore: store)
        let session = AppSession(environment: environment)
        await session.load()

        #expect(session.languagePreference == .system)
        session.selectLanguage(.korean)
        #expect(session.locale.identifier == "ko")
        #expect(store.preference() == .korean)

        let restoredSession = AppSession(environment: environment)
        #expect(restoredSession.languagePreference == .korean)
    }

    @Test func contributionPromptDismissalPreventsRepeatForThatOpportunity() async {
        let session = AppSession(environment: .development())
        await session.load()

        #expect(session.isContributionPromptVisible("missing-route-photo"))
        session.dismissContributionPrompt("missing-route-photo")
        #expect(!session.isContributionPromptVisible("missing-route-photo"))
        #expect(session.isContributionPromptVisible("stale-reset"))
    }

    @Test func routeColourAccessibilityNameIncludesReadableFixtureLabel() {
        #expect(RouteColourPresentation.accessibilityName(for: "  White  ") == "White")
        #expect(RouteColourPresentation.accessibilityName(for: "Yellow") == "Yellow")
    }

    @Test func betaRevealStateTransitionsOnlyAfterReveal() {
        var state = BetaRevealState.hidden
        #expect(!state.isRevealed)
        state.reveal()
        #expect(state == .revealed)
        #expect(state.isRevealed)
    }

    @Test func archivedPresentationCannotBeMistakenForCurrent() throws {
        let route = try #require(DevelopmentFixtures.routes.first { $0.lifecycle == .archived })
        #expect(RoutePresentationRules.showsArchivedBanner(route))
        #expect(!RoutePresentationRules.isCurrent(route))
    }

    @Test func filterActiveCountTracksEveryVisibleFilter() {
        let gymOptions = GymFilterOptions(
            openNow: true,
            facilities: [.parking, .showers],
            hasBeta: true,
            recentlyReset: true
        )
        #expect(gymOptions.activeCount == 5)

        let routeOptions = RouteListOptions(
            query: "White",
            gradeBand: .v3ToV5,
            hasBeta: true,
            sort: .mostBeta
        )
        #expect(routeOptions.activeFilterCount == 3)
        #expect(routeOptions.hasActiveFilters)
    }

    @Test func routeDetailRulesSeparateEstimateAndArchiveSignals() throws {
        let estimate = try #require(DevelopmentFixtures.routes.first {
            $0.expectedArchiveDate != nil && $0.isArchiveDateEstimated
        })
        let archived = try #require(DevelopmentFixtures.routes.first { $0.lifecycle == .archived })

        #expect(RoutePresentationRules.showsEstimateOnly(estimate))
        #expect(RoutePresentationRules.showsArchivedBanner(archived))
        #expect(!RoutePresentationRules.isCurrent(archived))
    }
}
