import Foundation
import Testing
@testable import BlocLens

@MainActor
struct RemoteBoundaryTests {
    private let decoder = RemoteJSONCoding.makeDecoder()

    @Test func repositoryErrorEquatableDistinguishesRemoteSemantics() {
        let cases: [RepositoryError] = [
            .notFound, .unavailable, .offline, .unauthenticated, .forbidden,
            .network, .timeout, .rateLimited, .decodingFailure,
            .invalidConfiguration, .unknown, .offlineNoCache
        ]
        for index in cases.indices {
            for other in cases.indices where index != other {
                #expect(cases[index] != cases[other])
            }
        }
    }

    @Test func gymHardSoftOverallDerivesFromBandRows() throws {
        let bands = [
            GymHardSoftBandRecord(gradeBand: "V0–V2", eligibleRouteCount: 5, medianGradeDelta: 1.0, assessment: "hard"),
            GymHardSoftBandRecord(gradeBand: "V3–V5", eligibleRouteCount: 3, medianGradeDelta: -0.5, assessment: "soft"),
            GymHardSoftBandRecord(gradeBand: "V6+", eligibleRouteCount: 2, medianGradeDelta: 0.0, assessment: "balanced"),
            GymHardSoftBandRecord(gradeBand: "Overall", eligibleRouteCount: 10, medianGradeDelta: 0.5, assessment: "hard")
        ]
        #expect(try GymHardSoftMapping.overallSummary(from: bands) == .hard)
    }

    @Test(arguments: [("soft", HardSoftSummary.soft), ("balanced", .balanced), ("hard", .hard)])
    func gymHardSoftOverallMapsEachAssessment(assessment: String, expected: HardSoftSummary) throws {
        let bands = [GymHardSoftBandRecord(gradeBand: "Overall", eligibleRouteCount: 3, medianGradeDelta: 0, assessment: assessment)]
        #expect(try GymHardSoftMapping.overallSummary(from: bands) == expected)
    }

    @Test func gymHardSoftInsufficientDataMapsToDomainState() throws {
        let bands = [GymHardSoftBandRecord(gradeBand: "Overall", eligibleRouteCount: 1, medianGradeDelta: nil, assessment: "not_enough_community_data")]
        #expect(try GymHardSoftMapping.overallSummary(from: bands) == .insufficientData)
    }

    @Test func gymHardSoftEmptyResultIsRejected() {
        #expect(throws: RemoteMappingError.self) {
            try GymHardSoftMapping.overallSummary(from: [])
        }
    }

    @Test func gymHardSoftMissingOverallBandIsRejected() {
        let bands = [GymHardSoftBandRecord(gradeBand: "V0–V2", eligibleRouteCount: 3, medianGradeDelta: 0, assessment: "balanced")]
        #expect(throws: RemoteMappingError.self) {
            try GymHardSoftMapping.overallSummary(from: bands)
        }
    }

    @Test func gymHardSoftUnknownAssessmentIsRejected() {
        let bands = [GymHardSoftBandRecord(gradeBand: "Overall", eligibleRouteCount: 3, medianGradeDelta: 0, assessment: "unknown")]
        #expect(throws: RemoteMappingError.self) {
            try GymHardSoftMapping.overallSummary(from: bands)
        }
    }

    @Test func routeAggregationComposesCommunityMedian() throws {
        let data = Data(#"""
        {
          "id":"30000000-0000-4000-8000-000000000001",
          "gym_id":"10000000-0000-4000-8000-000000000001",
          "wall_zone_id":"20000000-0000-4000-8000-000000000001",
          "colour":"Blue",
          "label":null,
          "gym_grade":2,
          "lifecycle":"active",
          "set_date":"2026-08-18T00:00:00Z",
          "estimated_archive_date":null,
          "is_archive_date_estimated":false,
          "archived_at":null,
          "beta_count":4
        }
        """#.utf8)
        let record = try decoder.decode(RouteRecord.self, from: data)
        let grade = CommunityGradeRecord(
            routeID: record.id,
            voteCount: 3,
            isDisplayEligible: true,
            medianVGrade: VGrade.v3.rawValue
        )
        let route = try record.domain(communityGrade: grade)
        #expect(route.lifecycle == .active)
        #expect(route.communityGradeSummary.displayGrade == .v3)
    }

    @Test func deletedLogbookRowIsRejectedAsActiveEntry() throws {
        let data = Data(#"""
        {
          "id":"60000000-0000-4000-8000-000000000001",
          "user_id":"90000000-0000-4000-8000-000000000001",
          "route_id":"30000000-0000-4000-8000-000000000001",
          "status":"projecting",
          "climbed_at":"2026-08-20T02:30:00Z",
          "attempts":4,
          "private_note":null,
          "predicted_v_grade":3,
          "client_created_at":"2026-08-20T02:30:00Z",
          "client_idempotency_key":"61000000-0000-4000-8000-000000000001",
          "created_at":"2026-08-20T02:30:00Z",
          "updated_at":"2026-08-20T02:30:00Z",
          "deleted_at":"2026-08-21T02:30:00Z"
        }
        """#.utf8)
        let record = try decoder.decode(LogbookEntryRecord.self, from: data)
        #expect(throws: RemoteMappingError.self) {
            try record.domain()
        }
    }

    @Test func publicProfileMapsOnlyPublicFields() throws {
        let data = Data(#"""
        {
          "id":"90000000-0000-4000-8000-000000000001",
          "username":"Development Climber",
          "avatar_path":"avatars/dev.png",
          "height_cm":170,
          "arm_span_cm":172,
          "regular_grade":4,
          "is_trusted_contributor":true,
          "helpful_received_count":99,
          "age_confirmed_16_plus_at":"2026-08-20T00:00:00Z"
        }
        """#.utf8)
        let record = try decoder.decode(PublicProfileRecord.self, from: data)
        let profile = try record.domain()

        #expect(profile.username == "Development Climber")
        #expect(profile.heightCentimetres == 170)
        #expect(profile.regularGrade == .v4)
        #expect(profile.isTrustedContributor)
        #expect(profile.userID.rawValue == "90000000-0000-4000-8000-000000000001")
    }

    @Test func environmentExposesNeutralAvailabilityInsteadOfScenario() async throws {
        #expect(AppEnvironment.development(scenario: .loaded).dataAvailability == .online)
        #expect(AppEnvironment.development(scenario: .empty).dataAvailability == .online)
        #expect(AppEnvironment.development(scenario: .error).dataAvailability == .online)
        #expect(AppEnvironment.development(scenario: .offlineWithoutCache).dataAvailability == .online)
        #expect(AppEnvironment.development(scenario: .offlineWithCache).dataAvailability == .offlineCached)

        let gyms = try await AppEnvironment.development().gymRepository.allGyms()
        #expect(!gyms.isEmpty)
    }

    @Test func remoteConfigurationRejectsInsecureOrEmptyValues() throws {
        let http = try #require(URL(string: "http://example.com"))
        #expect(throws: RepositoryError.self) {
            try RemoteConfiguration(projectURL: http, publishableKey: "key")
        }

        let https = try #require(URL(string: "https://example.com"))
        #expect(throws: RepositoryError.self) {
            try RemoteConfiguration(projectURL: https, publishableKey: "   ")
        }
    }

    @Test func remoteConfigurationAcceptsValidValues() throws {
        let https = try #require(URL(string: "https://abc.supabase.co"))
        let config = try RemoteConfiguration(projectURL: https, publishableKey: "publishable-key")
        #expect(config.publishableKey == "publishable-key")
        #expect(config.projectURL.absoluteString.hasPrefix("https://"))
    }
}
