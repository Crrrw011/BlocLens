import Testing
@testable import BlocLens

@MainActor
struct NavigationFoundationTests {
    @Test func appTabsExistInIntendedOrder() {
        #expect(AppTab.allCases == [.home, .map, .add, .logbook, .profile])
    }

    @Test func addActionsExistInIntendedOrder() {
        #expect(AddAction.allCases == [
            .publishBetaLink,
            .addNewRoute,
            .recordCompletedRoute,
            .identifyOrMarkRoute
        ])
    }

    @Test func noAddActionRepresentsDirectVideoUpload() {
        #expect(AddAction.allCases.allSatisfy { !$0.representsDirectVideoUpload })
        #expect(AddAction.publishBetaLink.betaMediaSource == .externalPublicLink)
        #expect(AddAction.allCases.dropFirst().allSatisfy { $0.betaMediaSource == nil })
    }

    @Test func defaultSelectedTabIsValid() {
        #expect(AppTab.allCases.contains(AppTab.defaultSelected))
        #expect(AppTab.defaultSelected == .home)
    }

    @Test func navigationPresentationMappingsAreComplete() {
        #expect(AppTab.allCases.allSatisfy { !$0.systemImage.isEmpty })
        #expect(AddAction.allCases.allSatisfy { !$0.systemImage.isEmpty })
    }
}
