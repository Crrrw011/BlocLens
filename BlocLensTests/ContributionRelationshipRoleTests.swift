import Foundation
import Testing
@testable import BlocLens

@MainActor
struct ContributionRepositoryTests {
    private var route: ClimbingRoute { DevelopmentFixtures.routes[0] }
    private var beta: BetaLink { DevelopmentFixtures.betaLinks[0] }

    @Test func addRouteSucceedsAndIsIdempotent() async throws {
        let repository = MockContributionRepository()
        let key = IdempotencyKey()
        let request = AddRouteRequest(
            idempotencyKey: key, gymID: route.gymID, wallZoneID: route.wallZoneID,
            colour: "Teal", terrain: .slab, styles: [.technical],
            subjectiveGrade: .v4, setDate: nil
        )

        let first = try await repository.addRoute(request)
        let second = try await repository.addRoute(request)

        #expect(first == second)
        #expect(first.colour == "Teal")
        #expect(first.terrain == .slab)
    }

    @Test func addRouteRejectsMissingIdentity() async {
        let repository = MockContributionRepository()
        do {
            _ = try await repository.addRoute(
                AddRouteRequest(
                    idempotencyKey: IdempotencyKey(), gymID: route.gymID,
                    wallZoneID: route.wallZoneID, colour: " ", terrain: .slab,
                    styles: [], subjectiveGrade: nil, setDate: nil
                )
            )
            Issue.record("Expected invalidInput")
        } catch let error as RepositoryError {
            #expect(error == .invalidInput)
        } catch { Issue.record("Unexpected error: \(error)") }
    }

    @Test func createWallZoneSucceedsAndIsIdempotent() async throws {
        let repository = MockContributionRepository()
        let key = IdempotencyKey()
        let gym = DevelopmentFixtures.gyms[0]
        let request = AddWallZoneRequest(
            idempotencyKey: key, gymID: gym.id, name: "  North Slab  ",
            locationDescription: "Left side", wallKind: .regularSetWall,
            surfaceMaterial: .plywood, surfaceTexture: .textured,
            hasBoltHoles: false, sortOrder: 4
        )

        let first = try await repository.createWallZone(request)
        let second = try await repository.createWallZone(request)

        #expect(first == second)
        #expect(first.name == "North Slab")
        #expect(first.locationDescription == "Left side")
        #expect(first.wallKind == .regularSetWall)
        #expect(first.surfaceMaterial == .plywood)
        #expect(first.surfaceTexture == .textured)
        #expect(first.hasBoltHoles == false)
        #expect(first.sortOrder == 4)
        #expect(first.gymID == gym.id)
    }

    @Test func createWallZoneRejectsBlankName() async {
        let repository = MockContributionRepository()
        let gym = DevelopmentFixtures.gyms[0]
        do {
            _ = try await repository.createWallZone(
                AddWallZoneRequest(
                    idempotencyKey: IdempotencyKey(), gymID: gym.id, name: "   ",
                    locationDescription: nil, wallKind: .sprayWall,
                    surfaceMaterial: .plywood, surfaceTexture: .smooth,
                    hasBoltHoles: true, sortOrder: 0
                )
            )
            Issue.record("Expected invalidInput")
        } catch let error as RepositoryError {
            #expect(error == .invalidInput)
        } catch { Issue.record("Unexpected error: \(error)") }
    }

    @Test func createWallZoneRejectsUnknownGym() async {
        let repository = MockContributionRepository()
        do {
            _ = try await repository.createWallZone(
                AddWallZoneRequest(
                    idempotencyKey: IdempotencyKey(), gymID: GymID(rawValue: "missing-gym"),
                    name: "Cave", locationDescription: nil, wallKind: .compWall,
                    surfaceMaterial: .plywood, surfaceTexture: .lightlyTextured,
                    hasBoltHoles: true, sortOrder: 0
                )
            )
            Issue.record("Expected invalidInput")
        } catch let error as RepositoryError {
            #expect(error == .invalidInput)
        } catch { Issue.record("Unexpected error: \(error)") }
    }

    @Test func shareBetaLinkStoresExternalMetadataOnly() async throws {
        let repository = MockContributionRepository()
        let request = ShareBetaLinkRequest(
            idempotencyKey: IdempotencyKey(), routeID: route.id,
            publicURL: try #require(URL(string: "https://example.com/beta/new")),
            platform: .youtube, originalAuthor: "Development Author",
            originalPostURL: try #require(URL(string: "https://example.com/post/new")),
            tags: [.fullSolution], contributorHeightCentimetres: nil,
            contributorArmSpanCentimetres: nil, embedSupport: .supported
        )

        let link = try await repository.shareBetaLink(request)

        #expect(link.sourceURL.scheme == "https")
        #expect(link.tags == [.fullSolution])
    }

    @Test func shareBetaLinkRejectsNonHTTPS() async throws {
        let repository = MockContributionRepository()
        do {
            _ = try await repository.shareBetaLink(
                ShareBetaLinkRequest(
                    idempotencyKey: IdempotencyKey(), routeID: route.id,
                    publicURL: try #require(URL(string: "file:///tmp/video.mov")),
                    platform: .other, originalAuthor: "Author",
                    originalPostURL: try #require(URL(string: "https://example.com/post")),
                    tags: [], contributorHeightCentimetres: nil,
                    contributorArmSpanCentimetres: nil, embedSupport: .sourcePlatformOnly
                )
            )
            Issue.record("Expected invalidExternalLink")
        } catch let error as RepositoryError {
            #expect(error == .invalidExternalLink)
        } catch { Issue.record("Unexpected error: \(error)") }
    }

    @Test func routePhotoStoresURLAndContributorCredit() async throws {
        let repository = MockContributionRepository()
        let photo = try await repository.addRoutePhoto(
            AddRoutePhotoRequest(
                idempotencyKey: IdempotencyKey(), routeID: route.id,
                publicImageURL: try #require(URL(string: "https://example.com/photo.jpg")),
                width: 1200, height: 900
            )
        )

        #expect(photo.routeID == route.id)
        #expect(photo.contributorID == DevelopmentFixtures.currentUserID)
    }

    @Test func routePhotoRejectsLocalFile() async throws {
        let repository = MockContributionRepository()
        do {
            _ = try await repository.addRoutePhoto(
                AddRoutePhotoRequest(
                    idempotencyKey: IdempotencyKey(), routeID: route.id,
                    publicImageURL: try #require(URL(string: "file:///tmp/photo.jpg")),
                    width: nil, height: nil
                )
            )
            Issue.record("Expected invalidInput")
        } catch let error as RepositoryError {
            #expect(error == .invalidInput)
        } catch { Issue.record("Unexpected error: \(error)") }
    }

    @Test func correctionSucceedsAndIsIdempotent() async throws {
        let repository = MockContributionRepository()
        let key = IdempotencyKey()
        let request = SubmitRouteCorrectionRequest(
            idempotencyKey: key, routeID: route.id, issue: .grade,
            proposedValue: "V4", explanation: "The current tag reads V4."
        )

        let first = try await repository.submitCorrection(request)
        let second = try await repository.submitCorrection(request)

        #expect(first == second)
        #expect(first.status == "open")
    }

    @Test func correctionRejectsOversizedExplanation() async {
        let repository = MockContributionRepository()
        do {
            _ = try await repository.submitCorrection(
                SubmitRouteCorrectionRequest(
                    idempotencyKey: IdempotencyKey(), routeID: route.id,
                    issue: .other, proposedValue: nil,
                    explanation: String(repeating: "a", count: 1_001)
                )
            )
            Issue.record("Expected invalidInput")
        } catch let error as RepositoryError {
            #expect(error == .invalidInput)
        } catch { Issue.record("Unexpected error: \(error)") }
    }

    @Test func resetConfirmationSucceedsAndIsIdempotent() async throws {
        let repository = MockContributionRepository()
        let key = IdempotencyKey()
        let request = ConfirmResetRequest(
            idempotencyKey: key, gymID: route.gymID,
            wallZoneID: route.wallZoneID, resetDate: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let first = try await repository.confirmReset(request)
        let second = try await repository.confirmReset(request)

        #expect(first == second)
        #expect(first.confirmationCount == 1)
    }

    @Test func resetConfirmationRejectsWrongGymZonePair() async {
        let repository = MockContributionRepository()
        guard let otherGym = DevelopmentFixtures.gyms.first(where: { $0.id != route.gymID }) else {
            Issue.record("Expected a second fixture gym")
            return
        }
        do {
            _ = try await repository.confirmReset(
                ConfirmResetRequest(
                    idempotencyKey: IdempotencyKey(), gymID: otherGym.id,
                    wallZoneID: route.wallZoneID, resetDate: Date(timeIntervalSince1970: 1_700_000_000)
                )
            )
            Issue.record("Expected invalidInput")
        } catch let error as RepositoryError {
            #expect(error == .invalidInput)
        } catch { Issue.record("Unexpected error: \(error)") }
    }

    @Test func commentSucceedsWithoutReplies() async throws {
        let repository = MockContributionRepository()
        let comment = try await repository.addComment(
            AddBetaCommentRequest(
                idempotencyKey: IdempotencyKey(), betaLinkID: beta.id,
                body: "Useful foot placement at the crux.", officialGymID: nil
            )
        )

        #expect(comment.body == "Useful foot placement at the crux.")
        let comments = await repository.comments(betaLinkID: beta.id)
        #expect(comments == [comment])
    }

    @Test func commentRejectsMoreThanTwoHundredCharacters() async {
        let repository = MockContributionRepository()
        do {
            _ = try await repository.addComment(
                AddBetaCommentRequest(
                    idempotencyKey: IdempotencyKey(), betaLinkID: beta.id,
                    body: String(repeating: "a", count: 201), officialGymID: nil
                )
            )
            Issue.record("Expected invalidInput")
        } catch let error as RepositoryError {
            #expect(error == .invalidInput)
        } catch { Issue.record("Unexpected error: \(error)") }
    }

    @Test func severeReportIsMarkedForImmediateThreshold() async throws {
        let repository = MockContributionRepository()
        let receipt = try await repository.reportContent(
            SubmitContentReportRequest(
                idempotencyKey: IdempotencyKey(), targetType: .betaLink,
                targetID: beta.id.rawValue, category: .minorPrivacy, details: nil
            )
        )

        #expect(receipt.isSevere)
    }

    @Test func reportRejectsMissingTarget() async {
        let repository = MockContributionRepository()
        do {
            _ = try await repository.reportContent(
                SubmitContentReportRequest(
                    idempotencyKey: IdempotencyKey(), targetType: .route,
                    targetID: "", category: .other, details: nil
                )
            )
            Issue.record("Expected invalidInput")
        } catch let error as RepositoryError {
            #expect(error == .invalidInput)
        } catch { Issue.record("Unexpected error: \(error)") }
    }

    @Test func submitFeedbackSucceedsAndIsIdempotent() async throws {
        let repository = MockContributionRepository()
        let key = IdempotencyKey()
        let request = SubmitFeedbackRequest(
            idempotencyKey: key, category: .suggestion,
            message: "  Please add a dark mode toggle.  ", currentPageID: nil
        )

        let first = try await repository.submitFeedback(request)
        let second = try await repository.submitFeedback(request)

        #expect(first == second)
        #expect(first.category == .suggestion)
    }

    @Test func submitFeedbackRejectsBlankMessage() async {
        let repository = MockContributionRepository()
        do {
            _ = try await repository.submitFeedback(
                SubmitFeedbackRequest(
                    idempotencyKey: IdempotencyKey(), category: .issue,
                    message: "   ", currentPageID: nil
                )
            )
            Issue.record("Expected invalidInput")
        } catch let error as RepositoryError {
            #expect(error == .invalidInput)
        } catch { Issue.record("Unexpected error: \(error)") }
    }
}

@MainActor
struct RelationshipAndRoleRepositoryTests {
    @Test func followAndUnfollowUpdateState() async throws {
        let repository = MockRelationshipRepository()
        let user = try #require(await repository.publicProfiles().first)

        try await repository.follow(userID: user.userID, idempotencyKey: IdempotencyKey())
        let followingState = await repository.state(with: user.userID)
        #expect(followingState.isFollowing)
        try await repository.unfollow(userID: user.userID, idempotencyKey: IdempotencyKey())
        let unfollowedState = await repository.state(with: user.userID)
        #expect(!unfollowedState.isFollowing)
    }

    @Test func followingBlockedUserFails() async throws {
        let repository = MockRelationshipRepository()
        let user = try #require(await repository.publicProfiles().first)
        try await repository.block(userID: user.userID, idempotencyKey: IdempotencyKey())

        do {
            try await repository.follow(userID: user.userID, idempotencyKey: IdempotencyKey())
            Issue.record("Expected invalidState")
        } catch let error as RepositoryError {
            #expect(error == .invalidState)
        } catch { Issue.record("Unexpected error: \(error)") }
    }

    @Test func blockCancelsFollowAndHidesProfile() async throws {
        let repository = MockRelationshipRepository()
        let user = try #require(await repository.publicProfiles().first)
        try await repository.follow(userID: user.userID, idempotencyKey: IdempotencyKey())
        try await repository.block(userID: user.userID, idempotencyKey: IdempotencyKey())

        let state = await repository.state(with: user.userID)
        #expect(state.isBlocked)
        #expect(!state.isFollowing)
        let visibleAfterBlock = await repository.publicProfiles()
        #expect(!visibleAfterBlock.contains { $0.userID == user.userID })
        let blockedProfiles = await repository.blockedProfiles()
        #expect(blockedProfiles.contains { $0.userID == user.userID })
    }

    @Test func unblockRestoresProfileVisibility() async throws {
        let repository = MockRelationshipRepository()
        let user = try #require(await repository.publicProfiles().first)
        try await repository.block(userID: user.userID, idempotencyKey: IdempotencyKey())
        try await repository.unblock(userID: user.userID, idempotencyKey: IdempotencyKey())

        let visibleAfterUnblock = await repository.publicProfiles()
        #expect(visibleAfterUnblock.contains { $0.userID == user.userID })
    }

    @Test func selfBlockFails() async {
        let repository = MockRelationshipRepository()
        do {
            try await repository.block(
                userID: DevelopmentFixtures.currentUserID,
                idempotencyKey: IdempotencyKey()
            )
            Issue.record("Expected invalidInput")
        } catch let error as RepositoryError {
            #expect(error == .invalidInput)
        } catch { Issue.record("Unexpected error: \(error)") }
    }

    @Test func trustedContributorAndVerifiedGymCapabilitiesAreScoped() async throws {
        let gymID = DevelopmentFixtures.gyms[0].id
        let context = SessionRoleContext(appRole: .trustedContributor, managedGymIDs: [gymID])
        let loaded = await MockRoleRepository(context: context).sessionRoleContext()

        #expect(loaded.isTrustedContributor)
        #expect(loaded.manages(gymID: gymID))
        #expect(!loaded.isModerator)
        #expect(!loaded.isAdministrator)
    }

    @Test func ordinaryUserHasNoPrivilegedCapabilities() async {
        let loaded = await MockRoleRepository(
            context: SessionRoleContext(appRole: .user, managedGymIDs: [])
        ).sessionRoleContext()

        #expect(!loaded.isTrustedContributor)
        #expect(!loaded.isModerator)
        #expect(!loaded.isAdministrator)
        #expect(loaded.managedGymIDs.isEmpty)
    }

    @Test func notificationPreferencesDefaultEnabledAndPersist() async throws {
        let repository = MockRoleRepository()

        let defaults = try await repository.notificationPreferences()
        #expect(defaults.count == NotificationCategory.allCases.count)
        #expect(defaults.allSatisfy { $0.isEnabled })

        try await repository.setNotificationPreference(category: .gymReset, isEnabled: false)
        let updated = try await repository.notificationPreferences()
        let gymReset = try #require(updated.first { $0.category == .gymReset })
        #expect(!gymReset.isEnabled)
    }
}
