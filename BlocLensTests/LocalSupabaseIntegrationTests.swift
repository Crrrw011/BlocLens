import XCTest
import Supabase
@testable import BlocLens

final class LocalSupabaseIntegrationTests: XCTestCase {
    private var configuration: RemoteConfiguration!
    private var client: SupabaseClient!

    override func setUp() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let urlString = environment["BLOCLENS_SUPABASE_URL"],
              !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let url = URL(string: urlString) else {
            throw XCTSkip("BLOCLENS_SUPABASE_URL is not set; skipping local integration tests.")
        }
        let key = environment["BLOCLENS_SUPABASE_ANON_KEY"] ?? ""
        configuration = try RemoteConfiguration(mode: .integrationTest, projectURL: url, publishableKey: key)
        client = SupabaseClientFactory.makeClient(configuration: configuration)
    }

    private func makeEnvironment() -> AppEnvironment {
        AppEnvironment.localSupabase(configuration: configuration)
    }

    func testReadsThreeGyms() async throws {
        let gyms = try await makeEnvironment().gymRepository.allGyms()
        XCTAssertEqual(gyms.count, 3)
    }

    func testReadsNineWallZones() async throws {
        let zones = try await makeEnvironment().gymRepository.allWallZones()
        XCTAssertEqual(zones.count, 9)
    }

    func testReadsVisibleRoutes() async throws {
        let routes = try await makeEnvironment().routeRepository.allRoutes()
        XCTAssertEqual(routes.count, 26)
    }

    func testGymFacilitiesAggregate() async throws {
        let gyms = try await makeEnvironment().gymRepository.allGyms()
        let westEnd = try XCTUnwrap(gyms.first { $0.name == "Urban Climb West End" })
        XCTAssertFalse(westEnd.facilities.isEmpty)
        XCTAssertEqual(westEnd.wallZoneIDs.count, 3)
    }

    func testHardSoftSummaryMaps() async throws {
        let gyms = try await makeEnvironment().gymRepository.allGyms()
        for gym in gyms {
            let summary = gym.overallHardSoftSummary
            XCTAssertTrue(
                summary == .hard || summary == .soft || summary == .balanced || summary == .insufficientData
            )
        }
    }

    func testArchivedRouteMapsDistinctly() async throws {
        let routes = try await makeEnvironment().routeRepository.allRoutes()
        let archived = try XCTUnwrap(routes.first { $0.id.rawValue == "30000000-0000-4000-8000-000000000027" })
        XCTAssertEqual(archived.lifecycle, .archived)
    }

    func testCommunityGradeThresholds() async throws {
        let routes = try await makeEnvironment().routeRepository.allRoutes()
        let threeVote = try XCTUnwrap(routes.first { $0.id.rawValue == "30000000-0000-4000-8000-000000000001" })
        XCTAssertEqual(threeVote.communityGradeSummary.voteCount, 3)
        XCTAssertEqual(threeVote.communityGradeSummary.displayGrade, .v3)

        let twoVote = try XCTUnwrap(routes.first { $0.id.rawValue == "30000000-0000-4000-8000-000000000002" })
        XCTAssertEqual(twoVote.communityGradeSummary.voteCount, 2)
        XCTAssertNil(twoVote.communityGradeSummary.displayGrade)
    }

    func testGuestSafeBetaCountExcludesHiddenBeta() async throws {
        let routes = try await makeEnvironment().routeRepository.allRoutes()
        let route = try XCTUnwrap(routes.first { $0.id.rawValue == "30000000-0000-4000-8000-000000000001" })
        XCTAssertEqual(route.betaCount, 3)
    }

    func testAnonymousCannotReadBetaLinks() async throws {
        do {
            let response: PostgrestResponse<[BetaLinkRecord]> = try await client
                .from("beta_links")
                .select()
                .execute()
            XCTFail("Expected beta_links read to be denied, got \(response.value.count) rows")
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            let mapped = RemoteErrorMapping.map(error)
            XCTAssertTrue(mapped == .forbidden || mapped == .unauthenticated, "Unexpected mapping \(mapped)")
        }
    }

    func testAnonymousCannotReadBetaRankingInputs() async throws {
        do {
            let response: PostgrestResponse<[BetaLinkRecord]> = try await client
                .from("beta_ranking_inputs")
                .select()
                .execute()
            XCTFail("Expected beta_ranking_inputs read to be denied, got \(response.value.count) rows")
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            let mapped = RemoteErrorMapping.map(error)
            XCTAssertTrue(mapped == .forbidden || mapped == .unauthenticated, "Unexpected mapping \(mapped)")
        }
    }
}
