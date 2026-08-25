import Foundation
import Testing
@testable import BlocLens

@MainActor
struct RemoteMappingTests {
    private let decoder = RemoteJSONCoding.makeDecoder()

    @Test func gymRecordDecodesSnakeCaseAndOptionalFields() throws {
        let data = Data(#"""
        {
          "id":"10000000-0000-4000-8000-000000000001",
          "name":"Development Gym",
          "brand_name":null,
          "latitude":-27.48,
          "longitude":153.01,
          "suburb":"West End",
          "state":"QLD",
          "is_verified":true,
          "data_source":"development_fixture",
          "beta_count":null,
          "latest_reset_date":"2026-08-20T02:30:00.123Z"
        }
        """#.utf8)

        let record = try decoder.decode(GymRecord.self, from: data)

        #expect(record.brandName == nil)
        #expect(record.betaCount == nil)
        #expect(record.latestResetDate != nil)
        #expect(record.isVerified)
    }

    @Test func timestampDecoderAcceptsFractionalAndWholeSeconds() throws {
        let fractional = Data(#"""
        {
          "id":"50000000-0000-4000-8000-000000000001",
          "gym_id":"10000000-0000-4000-8000-000000000001",
          "wall_zone_id":null,
          "reset_date":"2026-08-20T02:30:00.456Z",
          "source":"official",
          "confirmation_count":0,
          "is_estimated":false
        }
        """#.utf8)
        let whole = Data(#"""
        {
          "id":"50000000-0000-4000-8000-000000000002",
          "gym_id":"10000000-0000-4000-8000-000000000001",
          "wall_zone_id":null,
          "reset_date":"2026-08-20T02:30:00Z",
          "source":"official",
          "confirmation_count":0,
          "is_estimated":false
        }
        """#.utf8)

        let first = try decoder.decode(ResetRecord.self, from: fractional)
        let second = try decoder.decode(ResetRecord.self, from: whole)

        #expect(abs(first.resetDate.timeIntervalSince(second.resetDate) - 0.456) < 0.000_001)
    }

    @Test func UUIDsMapToStableLowercaseDomainIdentifiers() throws {
        let data = Data(#"""
        {
          "id":"10000000-0000-4000-8000-00000000000A",
          "name":"Development Gym",
          "brand_name":"Development Brand",
          "latitude":-27.48,
          "longitude":153.01,
          "suburb":"West End",
          "state":"QLD",
          "is_verified":false,
          "data_source":"development_fixture",
          "beta_count":0,
          "latest_reset_date":null
        }
        """#.utf8)

        let record = try decoder.decode(GymRecord.self, from: data)
        let gym = try record.domain(facilities: [], wallZones: [], hardSoft: .insufficientData)

        #expect(gym.id.rawValue == "10000000-0000-4000-8000-00000000000a")
    }

    @Test func unavailableFacilityRowsDoNotEnterTheDomainGym() throws {
        let gymID = try #require(
            UUID(uuidString: "10000000-0000-4000-8000-000000000001")
        )
        let record = GymRecord(
            id: gymID,
            name: "Development Gym",
            brandName: nil,
            latitude: -27.48,
            longitude: 153.01,
            suburb: "West End",
            state: "QLD",
            isVerified: false,
            dataSource: "development_fixture",
            betaCount: 0,
            latestResetDate: nil
        )
        let unavailable = GymFacilityRecord(
            gymID: gymID,
            facility: "showers",
            isAvailable: false
        )

        let gym = try record.domain(facilities: [unavailable], wallZones: [], hardSoft: .insufficientData)

        #expect(gym.facilities.isEmpty)
    }

    @Test func unknownEnumFailsSafely() throws {
        let data = Data(#"""
        {
          "route_id":"30000000-0000-4000-8000-000000000001",
          "vote_count":3,
          "is_display_eligible":true,
          "median_v_grade":99
        }
        """#.utf8)
        let record = try decoder.decode(CommunityGradeRecord.self, from: data)

        #expect(throws: RemoteMappingError.self) {
            try record.domain()
        }
    }

    @Test func archivedRouteMappingPreservesHistoryState() throws {
        let data = Data(#"""
        {
          "id":"30000000-0000-4000-8000-000000000027",
          "gym_id":"10000000-0000-4000-8000-000000000003",
          "wall_zone_id":"20000000-0000-4000-8000-000000000009",
          "colour":"Black",
          "label":null,
          "gym_grade":8,
          "lifecycle":"archived",
          "set_date":"2026-05-01T00:00:00Z",
          "estimated_archive_date":null,
          "is_archive_date_estimated":false,
          "archived_at":"2026-07-01T00:00:00Z",
          "beta_count":1
        }
        """#.utf8)
        let record = try decoder.decode(RouteRecord.self, from: data)
        let summary = CommunityGradeRecord(
            routeID: record.id,
            voteCount: 0,
            isDisplayEligible: false,
            medianVGrade: nil
        )

        let route = try record.domain(communityGrade: summary)

        #expect(route.lifecycle == .archived)
        #expect(route.officialGrade == .v8)
    }

    @Test func brokenBetaLinkMapsWithoutDiscardingMetadata() throws {
        let record = try decoder.decode(BetaLinkRecord.self, from: betaJSON(linkStatus: "broken"))
        let beta = try record.domain()

        #expect(beta.linkHealth == .broken)
        #expect(beta.sourceURL.scheme == "https")
        #expect(beta.originalAuthor == "Development Author")
    }

    @Test(arguments: ["file:///tmp/beta.mov", "data:video/mp4;base64,AAAA"])
    func betaMappingRejectsUnsafeURLSchemes(_ url: String) throws {
        let record = try decoder.decode(
            BetaLinkRecord.self,
            from: betaJSON(linkStatus: "healthy", publicURL: url)
        )

        #expect(throws: RemoteMappingError.self) {
            try record.domain()
        }
    }

    @Test func communityMedianIsPrivateBelowThreeVotes() throws {
        let record = CommunityGradeRecord(
            routeID: UUID(),
            voteCount: 2,
            isDisplayEligible: false,
            medianVGrade: nil
        )

        let summary = try record.domain()

        #expect(summary.voteCount == 2)
        #expect(summary.displayGrade == nil)
    }

    @Test func eligibleCommunityGradeMapsItsMedian() throws {
        let record = CommunityGradeRecord(
            routeID: UUID(),
            voteCount: 3,
            isDisplayEligible: true,
            medianVGrade: VGrade.v4.rawValue
        )

        let summary = try record.domain()

        #expect(summary.voteCount == 3)
        #expect(summary.displayGrade == .v4)
    }

    @Test func logbookMappingRemainsPrivateByDefault() throws {
        let data = Data(#"""
        {
          "id":"60000000-0000-4000-8000-000000000001",
          "user_id":"90000000-0000-4000-8000-000000000001",
          "route_id":"30000000-0000-4000-8000-000000000001",
          "status":"projecting",
          "climbed_at":"2026-08-20T02:30:00Z",
          "attempts":4,
          "private_note":"Only visible to the owner",
          "predicted_v_grade":4,
          "client_created_at":"2026-08-20T02:30:00Z",
          "client_idempotency_key":"61000000-0000-4000-8000-000000000001",
          "created_at":"2026-08-20T02:30:00Z",
          "updated_at":"2026-08-20T02:30:00Z",
          "deleted_at":null
        }
        """#.utf8)

        let record = try decoder.decode(LogbookEntryRecord.self, from: data)
        let entry = try record.domain()

        #expect(entry.privacy == .privateByDefault)
        #expect(entry.privateNote == "Only visible to the owner")
        #expect(entry.syncState == .synced)
    }

    @Test func fixtureAndSeedIdentifierContractIsComplete() {
        #expect(RemoteSeedIdentifiers.gyms.count == 3)
        #expect(RemoteSeedIdentifiers.wallZones.count == 9)
        #expect(RemoteSeedIdentifiers.routes.count == 27)
        #expect(RemoteSeedIdentifiers.betaLinks.count == 6)
        #expect(Set(DevelopmentFixtures.gyms.map(\.id.rawValue)) == Set(RemoteSeedIdentifiers.gyms.keys))
        #expect(Set(DevelopmentFixtures.wallZones.map(\.id.rawValue)) == Set(RemoteSeedIdentifiers.wallZones.keys))
        #expect(Set(DevelopmentFixtures.routes.map(\.id.rawValue)) == Set(RemoteSeedIdentifiers.routes.keys))
        #expect(Set(DevelopmentFixtures.betaLinks.map(\.id.rawValue)) == Set(RemoteSeedIdentifiers.betaLinks.keys))
        #expect(
            (Array(RemoteSeedIdentifiers.gyms.values)
                + Array(RemoteSeedIdentifiers.wallZones.values)
                + Array(RemoteSeedIdentifiers.routes.values)
                + Array(RemoteSeedIdentifiers.betaLinks.values))
                .allSatisfy { UUID(uuidString: $0) != nil }
        )
    }

    private func betaJSON(linkStatus: String, publicURL: String = "https://example.com/beta/one") -> Data {
        Data(#"""
        {
          "id":"40000000-0000-4000-8000-000000000001",
          "route_id":"30000000-0000-4000-8000-000000000001",
          "public_url":"\#(publicURL)",
          "platform":"youtube",
          "original_author_display_name":"Development Author",
          "original_post_url":"https://example.com/post/one",
          "tags":["full_solution","static"],
          "helpful_count":12,
          "submitter_height_cm":170,
          "submitter_arm_span_cm":172,
          "link_status":"\#(linkStatus)",
          "moderation_status":"visible",
          "embed_capability":"supported",
          "created_at":"2026-08-20T02:30:00Z"
        }
        """#.utf8)
    }
}
