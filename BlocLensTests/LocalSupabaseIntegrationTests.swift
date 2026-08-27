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
        // The SDK restores sessions from the Keychain. Ensure each test starts anonymous.
        try? await client.auth.signOut()
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
        let seedIDs = Set(RemoteSeedIdentifiers.routes.values)
        XCTAssertEqual(routes.filter { seedIDs.contains($0.id.rawValue) }.count, 26)
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

    // MARK: - Authentication

    private func makeAuthRepository() -> SupabaseAuthenticationRepository {
        SupabaseAuthenticationRepository(dataSource: SupabaseAuthDataSource(client: client))
    }

    private func makeBetaRepository() -> RemoteBetaRepository {
        RemoteBetaRepository(dataSource: SupabaseBetaDataSource(client: client))
    }

    private func signUpAndCompleteSetup() async throws -> UUID {
        let repository = makeAuthRepository()
        let email = "beta-\(UUID().uuidString.prefix(8))@example.com"
        _ = await repository.signUp(email: email, password: "password123")
        _ = await repository.confirmAge(isOver16: true)
        _ = await repository.updateUsername("beta-\(UUID().uuidString.prefix(8))")
        return try XCTUnwrap(client.auth.currentUser?.id)
    }

    private func signInFixture(_ email: String) async throws -> SessionRoleContext {
        let repository = makeAuthRepository()
        let state = await repository.signIn(email: email, password: "BlocLensLocalTest1!")
        guard case .signedIn = state else {
            throw XCTSkip("Local role fixture could not authenticate: \(email)")
        }
        return try await RemoteRoleRepository(
            dataSource: SupabaseRoleDataSource(client: client)
        ).sessionRoleContext()
    }

    private func insertBeta(routeID: String, submittedBy: UUID) async throws -> UUID {
        let betaID = UUID()
        let values: [String: AnyJSON] = [
            "id": AnyJSON.string(betaID.uuidString),
            "route_id": AnyJSON.string(routeID),
            "public_url": AnyJSON.string("https://example.com/beta/\(betaID.uuidString)"),
            "platform": AnyJSON.string("youtube"),
            "original_author_display_name": AnyJSON.string("Test Author"),
            "original_post_url": AnyJSON.string("https://example.com/post/\(betaID.uuidString)"),
            "submitted_by": AnyJSON.string(submittedBy.uuidString)
        ]
        _ = try await client.from("beta_links").insert(values, returning: .minimal).execute()
        return betaID
    }

    private func insertLogbookEntry(routeID: String, userID: UUID) async throws {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestamp = formatter.string(from: Date())
        let values: [String: AnyJSON] = [
            "user_id": AnyJSON.string(userID.uuidString),
            "route_id": AnyJSON.string(routeID),
            "status": AnyJSON.string("projecting"),
            "climbed_at": AnyJSON.string(timestamp),
            "client_created_at": AnyJSON.string(timestamp),
            "client_idempotency_key": AnyJSON.string(UUID().uuidString)
        ]
        _ = try await client.from("logbook_entries").insert(values, returning: .minimal).execute()
    }

    func testBetaMetadataAfterSignIn() async throws {
        let userID = try await signUpAndCompleteSetup()
        let routeID = "30000000-0000-4000-8000-000000000003"
        let betaID = try await insertBeta(routeID: routeID, submittedBy: userID)

        let metadata = try await makeBetaRepository().betaMetadata(
            for: ClimbingRouteID(rawValue: routeID)
        )

        XCTAssertTrue(metadata.contains { $0.id.rawValue == betaID.uuidString.lowercased() })
    }

    func testRevealBetaAfterSignIn() async throws {
        let userID = try await signUpAndCompleteSetup()
        let betaID = try await insertBeta(routeID: "30000000-0000-4000-8000-000000000003", submittedBy: userID)

        let beta = try await makeBetaRepository().revealBeta(BetaLinkID(rawValue: betaID.uuidString.lowercased()))

        XCTAssertEqual(beta.sourceURL.scheme, "https")
    }

    func testBetaMethodsRequireAuthentication() async throws {
        let repository = makeBetaRepository()
        do {
            _ = try await repository.betaMetadata(for: ClimbingRouteID(rawValue: "30000000-0000-4000-8000-000000000003"))
            XCTFail("Expected unauthenticated")
        } catch let error as RepositoryError {
            XCTAssertEqual(error, .unauthenticated)
        }
    }

    func testMarkHelpfulSucceedsOnSeedBeta() async throws {
        _ = try await signUpAndCompleteSetup()
        // Seed beta submitted by a seed user, so this is not a self-vote.
        let seedBetaID = "40000000-0000-4000-8000-000000000001"

        try await makeBetaRepository().markHelpful(BetaLinkID(rawValue: seedBetaID))
    }

    func testMarkHelpfulDuplicateReturnsConflict() async throws {
        _ = try await signUpAndCompleteSetup()
        let seedBetaID = "40000000-0000-4000-8000-000000000002"

        try await makeBetaRepository().markHelpful(BetaLinkID(rawValue: seedBetaID))
        do {
            try await makeBetaRepository().markHelpful(BetaLinkID(rawValue: seedBetaID))
            XCTFail("Expected conflict on duplicate Helpful")
        } catch let error as RepositoryError {
            XCTAssertEqual(error, .conflict)
        }
    }

    func testCommunityGradeVoteRequiresAttempt() async throws {
        _ = try await signUpAndCompleteSetup()
        let routeID = "30000000-0000-4000-8000-000000000003"
        let repository = makeBetaRepository()

        do {
            try await repository.communityGradeVote(
                routeID: ClimbingRouteID(rawValue: routeID),
                grade: .v4
            )
            XCTFail("Expected invalidState without a logbook attempt")
        } catch let error as RepositoryError {
            XCTAssertEqual(error, .invalidState)
        }
    }

    func testCommunityGradeVoteWithAttempt() async throws {
        let userID = try await signUpAndCompleteSetup()
        let routeID = "30000000-0000-4000-8000-000000000003"
        try await insertLogbookEntry(routeID: routeID, userID: userID)
        let repository = makeBetaRepository()

        try await repository.communityGradeVote(
            routeID: ClimbingRouteID(rawValue: routeID),
            grade: .v4
        )
        let vote = try await repository.myGradeVote(for: ClimbingRouteID(rawValue: routeID))
        XCTAssertEqual(vote, .v4)
    }

    func testSafetyConfirmationPersists() async throws {
        _ = try await signUpAndCompleteSetup()
        let repository = makeBetaRepository()

        let before = await repository.hasConfirmedSafety()
        XCTAssertFalse(before)
        try await repository.confirmSafety()
        let after = await repository.hasConfirmedSafety()
        XCTAssertTrue(after)
    }

    private func makeLogbookRepository() -> RemoteLogbookRepository {
        RemoteLogbookRepository(
            dataSource: SupabaseLogbookDataSource(client: client),
            queue: InMemoryLogbookQueue()
        )
    }

    private func makeLogbookEntry(
        userID: UUID,
        routeID: String,
        status: LogbookStatus,
        note: String? = nil
    ) -> LogbookEntry {
        LogbookEntry(
            id: LogbookEntryID(rawValue: UUID().uuidString.lowercased()),
            userID: UserID(rawValue: userID.uuidString.lowercased()),
            routeID: ClimbingRouteID(rawValue: routeID),
            status: status,
            date: Date(),
            attemptCount: 2,
            privateNote: note,
            predictedVGrade: .v4,
            syncState: .queued,
            privacy: .privateByDefault
        )
    }

    func testLogbookSaveAndRead() async throws {
        let userID = try await signUpAndCompleteSetup()
        let routeID = "30000000-0000-4000-8000-000000000003"
        let repository = makeLogbookRepository()

        let saved = try await repository.saveEntry(makeLogbookEntry(userID: userID, routeID: routeID, status: .sent))
        XCTAssertEqual(saved.syncState, .synced)

        let entries = try await repository.entries(userID: UserID(rawValue: userID.uuidString.lowercased()))
        XCTAssertTrue(entries.contains { $0.routeID.rawValue == routeID && $0.status == .sent })
    }

    func testLogbookPrivateNoteOwnerOnly() async throws {
        let ownerID = try await signUpAndCompleteSetup()
        let routeID = "30000000-0000-4000-8000-000000000003"
        let repository = makeLogbookRepository()

        _ = try await repository.saveEntry(
            makeLogbookEntry(userID: ownerID, routeID: routeID, status: .projecting, note: "secret note")
        )

        let ownerEntries = try await repository.entries(userID: UserID(rawValue: ownerID.uuidString.lowercased()))
        XCTAssertTrue(ownerEntries.contains { $0.privateNote == "secret note" })

        // Switch to a different user: the owner's entry must be invisible.
        _ = try await signUpAndCompleteSetup()
        let otherEntries = try await makeLogbookRepository().entries(
            userID: UserID(rawValue: (try XCTUnwrap(client.auth.currentUser?.id)).uuidString.lowercased())
        )
        XCTAssertFalse(otherEntries.contains { $0.routeID.rawValue == routeID && $0.privateNote == "secret note" })
    }

    func testLogbookSoftDelete() async throws {
        let userID = try await signUpAndCompleteSetup()
        let routeID = "30000000-0000-4000-8000-000000000003"
        let repository = makeLogbookRepository()

        let saved = try await repository.saveEntry(makeLogbookEntry(userID: userID, routeID: routeID, status: .flash))
        try await repository.deleteEntry(saved.id)

        let entries = try await repository.entries(userID: UserID(rawValue: userID.uuidString.lowercased()))
        XCTAssertFalse(entries.contains { $0.id == saved.id })
    }

    func testLogbookHasAttemptedRoute() async throws {
        let userID = try await signUpAndCompleteSetup()
        let routeID = "30000000-0000-4000-8000-000000000003"
        let repository = makeLogbookRepository()

        _ = try await repository.saveEntry(makeLogbookEntry(userID: userID, routeID: routeID, status: .projecting))

        let attempted = try await repository.hasAttemptedRoute(ClimbingRouteID(rawValue: routeID))
        XCTAssertTrue(attempted)
    }

    // MARK: - Contributions, relationships, and roles

    private func makeContributionRepository() -> RemoteContributionRepository {
        RemoteContributionRepository(dataSource: SupabaseContributionDataSource(client: client))
    }

    private func makeRelationshipRepository() -> RemoteRelationshipRepository {
        RemoteRelationshipRepository(dataSource: SupabaseRelationshipDataSource(client: client))
    }

    func testContributionWritesRequireAuthentication() async throws {
        let repository = makeContributionRepository()
        do {
            _ = try await repository.addRoute(
                AddRouteRequest(
                    idempotencyKey: IdempotencyKey(),
                    gymID: GymID(rawValue: "10000000-0000-4000-8000-000000000001"),
                    wallZoneID: WallZoneID(rawValue: "20000000-0000-4000-8000-000000000001"),
                    colour: "Integration Blue", label: nil, officialGrade: nil, setDate: nil
                )
            )
            XCTFail("Expected unauthenticated")
        } catch let error as RepositoryError {
            XCTAssertEqual(error, .unauthenticated)
        }
    }

    func testAddRouteContribution() async throws {
        _ = try await signUpAndCompleteSetup()
        let key = IdempotencyKey()
        let request = AddRouteRequest(
            idempotencyKey: key,
            gymID: GymID(rawValue: "10000000-0000-4000-8000-000000000001"),
            wallZoneID: WallZoneID(rawValue: "20000000-0000-4000-8000-000000000001"),
            colour: "Integration Teal", label: nil, officialGrade: .v4, setDate: Date()
        )

        let first = try await makeContributionRepository().addRoute(request)
        let second = try await makeContributionRepository().addRoute(request)

        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(first.colourOrTag, "Integration Teal")
    }

    func testShareExternalBetaLinkContribution() async throws {
        _ = try await signUpAndCompleteSetup()
        let unique = UUID().uuidString.lowercased()
        let link = try await makeContributionRepository().shareBetaLink(
            ShareBetaLinkRequest(
                idempotencyKey: IdempotencyKey(),
                routeID: ClimbingRouteID(rawValue: "30000000-0000-4000-8000-000000000003"),
                publicURL: try XCTUnwrap(URL(string: "https://example.com/beta/\(unique)")),
                platform: .youtube, originalAuthor: "Integration Author",
                originalPostURL: try XCTUnwrap(URL(string: "https://example.com/post/\(unique)")),
                tags: [.crux], contributorHeightCentimetres: nil,
                contributorArmSpanCentimetres: nil, embedSupport: .sourcePlatformOnly
            )
        )

        XCTAssertEqual(link.sourceURL.scheme, "https")
        XCTAssertEqual(link.tags, [.crux])
    }

    func testAddRoutePhotoMetadataContribution() async throws {
        let userID = try await signUpAndCompleteSetup()
        let photo = try await makeContributionRepository().addRoutePhoto(
            AddRoutePhotoRequest(
                idempotencyKey: IdempotencyKey(),
                routeID: ClimbingRouteID(rawValue: "30000000-0000-4000-8000-000000000003"),
                publicImageURL: try XCTUnwrap(URL(string: "https://example.com/route-photo/\(UUID().uuidString).jpg")),
                width: 1200, height: 900
            )
        )

        XCTAssertEqual(photo.contributorID.rawValue, userID.uuidString.lowercased())
        XCTAssertEqual(photo.publicImageURL.scheme, "https")
    }

    func testSubmitRouteCorrectionContribution() async throws {
        _ = try await signUpAndCompleteSetup()
        let receipt = try await makeContributionRepository().submitCorrection(
            SubmitRouteCorrectionRequest(
                idempotencyKey: IdempotencyKey(),
                routeID: ClimbingRouteID(rawValue: "30000000-0000-4000-8000-000000000003"),
                issue: .grade, proposedValue: "V4", explanation: "Integration correction"
            )
        )

        XCTAssertEqual(receipt.status, "open")
    }

    func testConfirmResetContribution() async throws {
        _ = try await signUpAndCompleteSetup()
        let receipt = try await makeContributionRepository().confirmReset(
            ConfirmResetRequest(
                idempotencyKey: IdempotencyKey(),
                gymID: GymID(rawValue: "10000000-0000-4000-8000-000000000001"),
                wallZoneID: WallZoneID(rawValue: "20000000-0000-4000-8000-000000000001"),
                resetDate: Date()
            )
        )

        XCTAssertEqual(receipt.state, .pending)
        XCTAssertEqual(receipt.confirmationCount, 1)
        XCTAssertFalse(receipt.isOfficial)
    }

    func testFlatBetaCommentContribution() async throws {
        _ = try await signUpAndCompleteSetup()
        let betaID = BetaLinkID(rawValue: "40000000-0000-4000-8000-000000000001")
        let repository = makeContributionRepository()
        let comment = try await repository.addComment(
            AddBetaCommentRequest(
                idempotencyKey: IdempotencyKey(), betaLinkID: betaID,
                body: "Integration comment", officialGymID: nil
            )
        )

        let comments = try await repository.comments(betaLinkID: betaID)
        XCTAssertTrue(comments.contains(comment))
        XCTAssertLessThanOrEqual(comment.body.count, 200)
    }

    func testContentReportContribution() async throws {
        _ = try await signUpAndCompleteSetup()
        let receipt = try await makeContributionRepository().reportContent(
            SubmitContentReportRequest(
                idempotencyKey: IdempotencyKey(), targetType: .betaLink,
                targetID: "40000000-0000-4000-8000-000000000002",
                category: .brokenLink, details: "Integration report"
            )
        )

        XCTAssertFalse(receipt.isSevere)
    }

    func testFollowBlockAndUnblockRelationship() async throws {
        let followerEmail = "follower-\(UUID().uuidString.prefix(8))@example.com"
        let auth = makeAuthRepository()
        _ = await auth.signUp(email: followerEmail, password: "password123")
        _ = await auth.confirmAge(isOver16: true)
        _ = await auth.updateUsername("follower-\(UUID().uuidString.prefix(8))")
        let followerID = try XCTUnwrap(client.auth.currentUser?.id)
        _ = try await auth.signOut()

        _ = await auth.signUp(
            email: "relationship-\(UUID().uuidString.prefix(8))@example.com",
            password: "password123"
        )
        _ = await auth.confirmAge(isOver16: true)
        _ = await auth.updateUsername("rel-\(UUID().uuidString.prefix(8))")
        let followedID = try XCTUnwrap(client.auth.currentUser?.id)
        _ = try await auth.signOut()
        _ = await auth.signIn(email: followerEmail, password: "password123")

        XCTAssertEqual(client.auth.currentUser?.id, followerID)
        let repository = makeRelationshipRepository()
        let target = UserID(rawValue: followedID.uuidString.lowercased())
        try await repository.follow(userID: target, idempotencyKey: IdempotencyKey())
        let followed = try await repository.state(with: target)
        XCTAssertTrue(followed.isFollowing)
        try await repository.block(userID: target, idempotencyKey: IdempotencyKey())
        let blocked = try await repository.state(with: target)
        XCTAssertTrue(blocked.isBlocked)
        XCTAssertFalse(blocked.isFollowing)
        try await repository.unblock(userID: target, idempotencyKey: IdempotencyKey())
        let unblocked = try await repository.state(with: target)
        XCTAssertFalse(unblocked.isBlocked)
    }

    func testOrdinarySessionRoleContextDoesNotExposePrivilegedRoleRows() async throws {
        _ = try await signUpAndCompleteSetup()
        let context = try await RemoteRoleRepository(
            dataSource: SupabaseRoleDataSource(client: client)
        ).sessionRoleContext()

        XCTAssertEqual(context.appRole, .user)
        XCTAssertTrue(context.managedGymIDs.isEmpty)
        XCTAssertFalse(context.isModerator)
    }

    func testDeterministicTrustedContributorRoleFixture() async throws {
        let context = try await signInFixture("fixture-trusted@bloclens.invalid")
        XCTAssertEqual(context.appRole, .trustedContributor)
        XCTAssertTrue(context.managedGymIDs.isEmpty)
    }

    func testDeterministicVerifiedGymRoleFixtureIsGymScoped() async throws {
        let context = try await signInFixture("fixture-gym-official@bloclens.invalid")
        XCTAssertEqual(context.appRole, .user)
        XCTAssertEqual(
            context.managedGymIDs,
            [GymID(rawValue: "10000000-0000-4000-8000-000000000001")]
        )
        XCTAssertFalse(context.manages(gymID: GymID(rawValue: "10000000-0000-4000-8000-000000000002")))
    }

    func testDeterministicModeratorAndAdministratorRoleFixtures() async throws {
        let moderator = try await signInFixture("fixture-moderator@bloclens.invalid")
        XCTAssertEqual(moderator.appRole, .moderator)
        _ = try await makeAuthRepository().signOut()

        let administrator = try await signInFixture("fixture-admin@bloclens.invalid")
        XCTAssertEqual(administrator.appRole, .administrator)
        XCTAssertTrue(administrator.isAdministrator)
    }

    func testRevokedGymMembershipImmediatelyRemovesDatabaseCapability() async throws {
        _ = try await signInFixture("fixture-admin@bloclens.invalid")
        let timestamp = ISO8601DateFormatter().string(from: Date())
        _ = try await client.from("gym_memberships")
            .update(["revoked_at": timestamp], returning: .minimal)
            .eq("gym_id", value: "10000000-0000-4000-8000-000000000001")
            .eq("user_id", value: "90000000-0000-4000-8000-000000000005")
            .execute()
        _ = try await makeAuthRepository().signOut()

        let revoked = try await signInFixture("fixture-gym-official@bloclens.invalid")
        XCTAssertTrue(revoked.managedGymIDs.isEmpty)
        _ = try await makeAuthRepository().signOut()

        _ = try await signInFixture("fixture-admin@bloclens.invalid")
        _ = try await client.from("gym_memberships")
            .update(["revoked_at": AnyJSON.null], returning: .minimal)
            .eq("gym_id", value: "10000000-0000-4000-8000-000000000001")
            .eq("user_id", value: "90000000-0000-4000-8000-000000000005")
            .execute()
    }

    // MARK: - Authentication

    func testLocalSignUpThenProfileSetupThenUsername() async throws {
        let repository = makeAuthRepository()
        let email = "auth-\(UUID().uuidString.prefix(8))@example.com"

        let signedUp = await repository.signUp(email: email, password: "password123")
        guard case .profileSetup = signedUp else {
            return XCTFail("Expected profileSetup after signUp, got \(signedUp)")
        }

        let ageConfirmed = await repository.confirmAge(isOver16: true)
        guard case .profileSetup = ageConfirmed else {
            return XCTFail("Expected profileSetup after age confirmation, got \(ageConfirmed)")
        }

        let updated = await repository.updateUsername("climber-\(UUID().uuidString.prefix(8))")
        guard case .signedIn = updated else {
            return XCTFail("Expected signedIn after username update, got \(updated)")
        }
    }

    func testLocalSignInWrongPassword() async throws {
        let repository = makeAuthRepository()
        let email = "auth-\(UUID().uuidString.prefix(8))@example.com"
        _ = await repository.signUp(email: email, password: "password123")
        _ = try await repository.signOut()

        let state = await repository.signIn(email: email, password: "wrong-password")
        XCTAssertEqual(state, .error(.unauthenticated))
    }

    func testLocalSignInUnknownUser() async throws {
        let repository = makeAuthRepository()
        let email = "nobody-\(UUID().uuidString.prefix(8))@example.com"
        let state = await repository.signIn(email: email, password: "password123")
        XCTAssertEqual(state, .error(.unauthenticated))
    }

    func testLocalSignOutClearsSession() async throws {
        let repository = makeAuthRepository()
        let email = "auth-\(UUID().uuidString.prefix(8))@example.com"
        _ = await repository.signUp(email: email, password: "password123")
        _ = await repository.updateUsername("climber-\(UUID().uuidString.prefix(8))")

        let signedOut = try await repository.signOut()
        XCTAssertEqual(signedOut, .guest)

        let restored = await repository.restoreSession()
        XCTAssertEqual(restored, .guest)
    }
}
