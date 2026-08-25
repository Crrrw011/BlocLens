import Foundation
import Testing
@testable import BlocLens

@MainActor
struct FixtureIntegrityTests {
    @Test func threeGymFixtureRelationshipsAreComplete() {
        #expect(DevelopmentFixtures.gyms.count == 3)
        #expect(DevelopmentFixtures.wallZones.count == 9)
        #expect(DevelopmentFixtures.routes.count == 27)
        #expect(DevelopmentFixtures.gyms.allSatisfy { $0.wallZoneIDs.count == 3 })
    }

    @Test func wallZonesBelongToTheirDeclaredGyms() {
        let gymsByID = Dictionary(uniqueKeysWithValues: DevelopmentFixtures.gyms.map { ($0.id, $0) })
        for zone in DevelopmentFixtures.wallZones {
            #expect(gymsByID[zone.gymID]?.wallZoneIDs.contains(zone.id) == true)
        }
    }

    @Test func climbingRoutesBelongToTheirDeclaredWallZones() {
        let zonesByID = Dictionary(uniqueKeysWithValues: DevelopmentFixtures.wallZones.map { ($0.id, $0) })
        for route in DevelopmentFixtures.routes {
            #expect(zonesByID[route.wallZoneID]?.gymID == route.gymID)
        }
    }

    @Test func fixtureCoversRequiredLifecycleAndBetaStates() {
        #expect(DevelopmentFixtures.routes.contains { $0.lifecycle == .archived })
        #expect(DevelopmentFixtures.routes.contains { $0.expectedArchiveDate != nil && $0.isArchiveDateEstimated })
        #expect(DevelopmentFixtures.routes.contains { $0.betaCount == 0 })
        #expect(DevelopmentFixtures.routes.contains { $0.betaCount > 1 })
        #expect(DevelopmentFixtures.betaLinks.contains { $0.linkHealth == .broken })
        #expect(DevelopmentFixtures.betaLinks.contains { $0.embedSupport == .sourcePlatformOnly })
    }

    @Test func wallZoneModelContainsNoMapGeometry() {
        let labels = Set(Mirror(reflecting: DevelopmentFixtures.wallZones[0]).children.compactMap(\.label))
        #expect(labels.isDisjoint(with: ["coordinate", "geometry", "polygon", "hotspot", "floorPlan"]))
    }
}

@MainActor
struct GradeDomainTests {
    @Test func vGradesSortFromVBThroughV17WithUnknownLast() {
        let input: [VGrade] = [.unknown, .v8, .vb, .v17, .v0, .v3]
        #expect(input.sorted() == [.vb, .v0, .v3, .v8, .v17, .unknown])
    }

    @Test func legalGradeStringsParse() {
        #expect(VGrade(displayName: " VB ") == .vb)
        #expect(VGrade(displayName: "v0") == .v0)
        #expect(VGrade(displayName: "V17") == .v17)
        #expect(VGrade(displayName: "Unknown") == .unknown)
    }

    @Test func illegalGradeStringsFail() {
        #expect(VGrade(displayName: "V18") == nil)
        #expect(VGrade(displayName: "6A") == nil)
        #expect(VGrade(displayName: "") == nil)
    }

    @Test func fewerThanThreeVotesDoNotDisplayCommunityGrade() {
        let summary = CommunityGradeSummary(votes: [.v3, .v4])
        #expect(summary.voteCount == 2)
        #expect(summary.displayGrade == nil)
    }

    @Test func threeOrMoreVotesUseMedianRatherThanAverage() {
        let summary = CommunityGradeSummary(votes: [.v2, .v8, .v4, .v5, .v3])
        #expect(summary.voteCount == 5)
        #expect(summary.displayGrade == .v4)
    }
}

@MainActor
struct BetaDomainTests {
    @Test func betaAcceptsOnlyHTTPAndHTTPSURLs() {
        #expect(validates("https://example.com/beta"))
        #expect(validates("http://example.com/beta"))
        #expect(!validates("ftp://example.com/beta"))
    }

    @Test func betaRejectsFileDataAndLocalPaths() {
        #expect(!BetaLink.isValidExternalURL(URL(fileURLWithPath: "/tmp/video.mov")))
        #expect(!validates("data:video/mp4;base64,AAAA"))
        #expect(!validates("/Users/example/video.mov"))
    }

    @Test func bodyMatchSortsBeforeHelpfulCount() {
        let links = DevelopmentFixtures.betaLinks.filter { $0.routeID == "west-end-slab-r1" }
        let viewer = BetaViewerProfile(heightCentimetres: 166, armSpanCentimetres: 165)
        let result = BetaRanker.visibleLinks(links, viewer: viewer)
        #expect(result.map(\.id.rawValue) == ["beta-west-end-1-a", "beta-west-end-1-b"])
    }

    @Test func absentBodyProfileUsesHelpfulCount() {
        let links = DevelopmentFixtures.betaLinks.filter { $0.routeID == "west-end-slab-r1" }
        let result = BetaRanker.visibleLinks(links, viewer: nil)
        #expect(result.map(\.id.rawValue) == ["beta-west-end-1-b", "beta-west-end-1-a"])
    }

    @Test func brokenAndHiddenBetaAreFiltered() {
        let links = DevelopmentFixtures.betaLinks.filter { $0.routeID == "west-end-slab-r1" }
        let result = BetaRanker.visibleLinks(links, viewer: nil)
        #expect(result.allSatisfy { $0.linkHealth == .healthy && $0.moderationState == .visible })
        #expect(result.count == 2)
    }

    @Test func betaRepositoryStoresOnlyValidExternalMetadata() async throws {
        let repository = MockBetaRepository()
        let result = try await repository.betaLinks(routeID: "west-end-slab-r1", viewer: nil)
        #expect(result.allSatisfy { BetaLink.isValidExternalURL($0.sourceURL) })
    }

    private func validates(_ value: String) -> Bool {
        guard let url = URL(string: value) else { return false }
        return BetaLink.isValidExternalURL(url)
    }
}

@MainActor
struct LogbookRepositoryTests {
    private let date = Date(timeIntervalSince1970: 1_780_000_000)

    @Test func quickLogbookSavesImmediatelyAndPrivately() async {
        let repository = MockLogbookRepository(entries: [])
        let entry = await repository.saveStatus(
            userID: "test-user",
            routeID: "west-end-slab-r1",
            status: .projecting,
            date: date
        )
        #expect(entry.status == .projecting)
        #expect(entry.privacy == .privateByDefault)
        #expect(await repository.entry(userID: "test-user", routeID: "west-end-slab-r1") == entry)
    }

    @Test func offlineSaveQueuesThenSynchronisesWhenOnline() async {
        let repository = MockLogbookRepository(entries: [], isOnline: false)
        let queued = await repository.saveStatus(
            userID: "test-user",
            routeID: "west-end-slab-r1",
            status: .wantToTry,
            date: date
        )
        #expect(queued.syncState == .queued)
        await repository.setOnline(true)
        _ = await repository.synchroniseQueuedEntries()
        #expect(await repository.entry(userID: "test-user", routeID: "west-end-slab-r1")?.syncState == .synced)
    }

    @Test func flashCanBeSavedManually() async {
        let repository = MockLogbookRepository(entries: [])
        let entry = await repository.saveStatus(
            userID: "test-user",
            routeID: "west-end-cave-r2",
            status: .flash,
            date: date
        )
        #expect(entry.status == .flash)
    }

    @Test func logbookStatisticsAreCorrect() {
        let routesByID = Dictionary(uniqueKeysWithValues: DevelopmentFixtures.routes.map { ($0.id, $0) })
        let statistics = LogbookStatistics.calculate(
            entries: DevelopmentFixtures.logbookEntries,
            routesByID: routesByID
        )
        #expect(statistics.climbingCount == 3)
        #expect(statistics.sentCount == 1)
        #expect(statistics.flashCount == 1)
        #expect(statistics.highestGrade == .v7)
        #expect(statistics.gradeDistribution == [.v3: 1, .v7: 1])
    }
}
