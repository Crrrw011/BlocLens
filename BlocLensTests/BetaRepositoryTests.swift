import Foundation
import Supabase
import Testing
@testable import BlocLens

@MainActor
struct BetaRepositoryTests {
    private func uuid(_ suffix: Int) throws -> UUID {
        try #require(UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", suffix)))
    }

    private func makeBetaRecord(
        id: UUID,
        routeID: UUID,
        submittedBy: UUID?,
        helpful: Int = 0
    ) -> BetaLinkRecord {
        BetaLinkRecord(
            id: id, routeID: routeID, publicURL: "https://example.com/beta/\(id.uuidString)",
            platform: "youtube", originalAuthorDisplayName: "Development Author",
            originalPostURL: "https://example.com/post/\(id.uuidString)", tags: ["full_solution"],
            helpfulCount: helpful, submitterHeightCM: nil, submitterArmSpanCM: nil,
            linkStatus: "healthy", moderationStatus: "visible", embedCapability: "supported",
            createdAt: Date(), submittedBy: submittedBy
        )
    }

    private func makeRepository(_ dataSource: FakeBetaDataSource) -> RemoteBetaRepository {
        RemoteBetaRepository(dataSource: dataSource)
    }

    @Test func betaMetadataReturnsVisibleBeta() async throws {
        let routeID = try uuid(1)
        let submitter = try uuid(2)
        let betaID = try uuid(3)
        let dataSource = FakeBetaDataSource()
        dataSource.userIDValue = try uuid(4)
        dataSource.betaRecords = [makeBetaRecord(id: betaID, routeID: routeID, submittedBy: submitter)]

        let links = try await makeRepository(dataSource).betaMetadata(for: ClimbingRouteID(rawValue: routeID.uuidString.lowercased()))

        #expect(links.count == 1)
        #expect(links[0].id.rawValue == betaID.uuidString.lowercased())
    }

    @Test func betaMetadataReturnsEmptyForRouteWithoutBeta() async throws {
        let routeID = try uuid(1)
        let dataSource = FakeBetaDataSource()
        dataSource.userIDValue = try uuid(4)

        let links = try await makeRepository(dataSource).betaMetadata(for: ClimbingRouteID(rawValue: routeID.uuidString.lowercased()))

        #expect(links.isEmpty)
    }

    @Test func betaMetadataFiltersBlockedSubmitters() async throws {
        let routeID = try uuid(1)
        let blocked = try uuid(2)
        let allowed = try uuid(3)
        let viewer = try uuid(4)
        let dataSource = FakeBetaDataSource()
        dataSource.userIDValue = viewer
        dataSource.blockedIDs = [blocked]
        dataSource.betaRecords = [
            makeBetaRecord(id: try uuid(5), routeID: routeID, submittedBy: blocked),
            makeBetaRecord(id: try uuid(6), routeID: routeID, submittedBy: allowed)
        ]

        let links = try await makeRepository(dataSource).betaMetadata(for: ClimbingRouteID(rawValue: routeID.uuidString.lowercased()))
        let allowedID = try uuid(6)

        #expect(links.count == 1)
        #expect(links[0].id.rawValue == allowedID.uuidString.lowercased())
    }

    @Test func betaMetadataRequiresAuthentication() async throws {
        let routeID = try uuid(1)
        let dataSource = FakeBetaDataSource()
        dataSource.userIDValue = nil

        do {
            _ = try await makeRepository(dataSource).betaMetadata(for: ClimbingRouteID(rawValue: routeID.uuidString.lowercased()))
            Issue.record("Expected unauthenticated")
        } catch let error as RepositoryError {
            #expect(error == .unauthenticated)
        }
    }

    @Test func revealBetaReturnsFullRecord() async throws {
        let routeID = try uuid(1)
        let betaID = try uuid(2)
        let submitter = try uuid(3)
        let dataSource = FakeBetaDataSource()
        dataSource.userIDValue = try uuid(4)
        dataSource.betaRecords = [makeBetaRecord(id: betaID, routeID: routeID, submittedBy: submitter)]

        let beta = try await makeRepository(dataSource).revealBeta(BetaLinkID(rawValue: betaID.uuidString.lowercased()))

        #expect(beta.id.rawValue == betaID.uuidString.lowercased())
        #expect(beta.sourceURL.scheme == "https")
    }

    @Test func revealBetaMissingReturnsNotFound() async throws {
        let dataSource = FakeBetaDataSource()
        dataSource.userIDValue = try uuid(4)

        do {
            _ = try await makeRepository(dataSource).revealBeta(BetaLinkID(rawValue: try uuid(99).uuidString.lowercased()))
            Issue.record("Expected notFound")
        } catch let error as RepositoryError {
            #expect(error == .notFound)
        }
    }

    @Test func revealBetaRequiresAuthentication() async throws {
        let dataSource = FakeBetaDataSource()
        dataSource.userIDValue = nil

        do {
            _ = try await makeRepository(dataSource).revealBeta(BetaLinkID(rawValue: try uuid(1).uuidString.lowercased()))
            Issue.record("Expected unauthenticated")
        } catch let error as RepositoryError {
            #expect(error == .unauthenticated)
        }
    }

    @Test func markHelpfulSucceeds() async throws {
        let dataSource = FakeBetaDataSource()
        dataSource.userIDValue = try uuid(4)

        try await makeRepository(dataSource).markHelpful(BetaLinkID(rawValue: try uuid(1).uuidString.lowercased()))
    }

    @Test func markHelpfulDuplicateReturnsConflict() async throws {
        let dataSource = FakeBetaDataSource()
        dataSource.userIDValue = try uuid(4)
        dataSource.helpfulError = PostgrestError(code: "23505", message: "duplicate")

        do {
            try await makeRepository(dataSource).markHelpful(BetaLinkID(rawValue: try uuid(1).uuidString.lowercased()))
            Issue.record("Expected conflict")
        } catch let error as RepositoryError {
            #expect(error == .conflict)
        }
    }

    @Test func reportBetaSucceeds() async throws {
        let dataSource = FakeBetaDataSource()
        dataSource.userIDValue = try uuid(4)

        try await makeRepository(dataSource).reportBeta(
            BetaLinkID(rawValue: try uuid(1).uuidString.lowercased()),
            reason: .brokenLink
        )
    }

    @Test func reportBetaRequiresAuthentication() async throws {
        let dataSource = FakeBetaDataSource()
        dataSource.userIDValue = nil

        do {
            try await makeRepository(dataSource).reportBeta(
                BetaLinkID(rawValue: try uuid(1).uuidString.lowercased()),
                reason: .unsafeContent
            )
            Issue.record("Expected unauthenticated")
        } catch let error as RepositoryError {
            #expect(error == .unauthenticated)
        }
    }

    @Test func communityGradeVoteSucceedsWithAttempt() async throws {
        let routeID = try uuid(1)
        let dataSource = FakeBetaDataSource()
        dataSource.userIDValue = try uuid(2)
        dataSource.hasAttempt = true

        try await makeRepository(dataSource).communityGradeVote(
            routeID: ClimbingRouteID(rawValue: routeID.uuidString.lowercased()),
            grade: .v4
        )
        #expect(dataSource.gradeVotes[routeID] == VGrade.v4.rawValue)
    }

    @Test func communityGradeVoteWithoutAttemptReturnsInvalidState() async throws {
        let routeID = try uuid(1)
        let dataSource = FakeBetaDataSource()
        dataSource.userIDValue = try uuid(2)
        dataSource.hasAttempt = false

        do {
            try await makeRepository(dataSource).communityGradeVote(
                routeID: ClimbingRouteID(rawValue: routeID.uuidString.lowercased()),
                grade: .v4
            )
            Issue.record("Expected invalidState")
        } catch let error as RepositoryError {
            #expect(error == .invalidState)
        }
    }

    @Test func communityGradeVoteRejectsUnknownGrade() async throws {
        let routeID = try uuid(1)
        let dataSource = FakeBetaDataSource()
        dataSource.userIDValue = try uuid(2)
        dataSource.hasAttempt = true

        do {
            try await makeRepository(dataSource).communityGradeVote(
                routeID: ClimbingRouteID(rawValue: routeID.uuidString.lowercased()),
                grade: .unknown
            )
            Issue.record("Expected invalidInput")
        } catch let error as RepositoryError {
            #expect(error == .invalidInput)
        }
    }

    @Test func myGradeVoteReturnsCurrentVote() async throws {
        let routeID = try uuid(1)
        let dataSource = FakeBetaDataSource()
        dataSource.userIDValue = try uuid(2)
        dataSource.gradeVotes[routeID] = VGrade.v5.rawValue

        let vote = try await makeRepository(dataSource).myGradeVote(for: ClimbingRouteID(rawValue: routeID.uuidString.lowercased()))

        #expect(vote == .v5)
    }

    @Test func myGradeVoteReturnsNilWhenAbsent() async throws {
        let routeID = try uuid(1)
        let dataSource = FakeBetaDataSource()
        dataSource.userIDValue = try uuid(2)

        let vote = try await makeRepository(dataSource).myGradeVote(for: ClimbingRouteID(rawValue: routeID.uuidString.lowercased()))

        #expect(vote == nil)
    }

    @Test func safetyConfirmationStartsUnconfirmed() async throws {
        let dataSource = FakeBetaDataSource()
        let repository = makeRepository(dataSource)

        #expect(await repository.hasConfirmedSafety() == false)
    }

    @Test func safetyConfirmationPersistsAfterConfirm() async throws {
        let dataSource = FakeBetaDataSource()
        dataSource.userIDValue = try uuid(1)
        let repository = makeRepository(dataSource)

        try await repository.confirmSafety()

        #expect(await repository.hasConfirmedSafety() == true)
    }

    @Test func mockBetaRepositoryMarksHelpfulOnce() async throws {
        let repository = MockBetaRepository()
        let betaID = BetaLinkID(rawValue: "beta-west-end-1-a")

        try await repository.markHelpful(betaID)
        do {
            try await repository.markHelpful(betaID)
            Issue.record("Expected conflict on duplicate Helpful")
        } catch let error as RepositoryError {
            #expect(error == .conflict)
        }
    }
}

private final class FakeBetaDataSource: RemoteBetaDataSource, @unchecked Sendable {
    var userIDValue: UUID?
    var safetyConfirmed = false
    var blockedIDs: [UUID] = []
    var betaRecords: [BetaLinkRecord] = []
    var helpfulError: Error?
    var reportError: Error?
    var hasAttempt = false
    var gradeVoteError: Error?
    var gradeVotes: [UUID: Int] = [:]

    func currentUserID() -> UUID? { userIDValue }

    func hasConfirmedSafety() -> Bool { safetyConfirmed }

    func confirmSafety() async throws { safetyConfirmed = true }

    func fetchBlockedUserIDs(blockerID: UUID) async throws -> [UUID] { blockedIDs }

    func fetchBetaLinks(routeID: UUID) async throws -> [BetaLinkRecord] {
        betaRecords.filter { $0.routeID == routeID }
    }

    func fetchBetaLink(betaID: UUID) async throws -> BetaLinkRecord {
        guard let record = betaRecords.first(where: { $0.id == betaID }) else {
            throw PostgrestError(code: "PGRST116", message: "not found")
        }
        return record
    }

    func insertHelpfulVote(betaID: UUID, userID: UUID) async throws {
        if let helpfulError { throw helpfulError }
    }

    func insertReport(betaID: UUID, reporterID: UUID, category: String) async throws {
        if let reportError { throw reportError }
    }

    func hasValidAttempt(routeID: UUID) async throws -> Bool { hasAttempt }

    func insertGradeVote(routeID: UUID, userID: UUID, grade: Int) async throws {
        if let gradeVoteError { throw gradeVoteError }
        gradeVotes[routeID] = grade
    }

    func updateGradeVote(routeID: UUID, userID: UUID, grade: Int) async throws {
        if let gradeVoteError { throw gradeVoteError }
        gradeVotes[routeID] = grade
    }

    func fetchMyGradeVote(routeID: UUID, userID: UUID) async throws -> Int? {
        gradeVotes[routeID]
    }
}
