import Foundation

actor MockContributionRepository: ContributionRepository {
    private var routesByKey: [IdempotencyKey: ClimbingRoute] = [:]
    private var zonesByKey: [IdempotencyKey: WallZone] = [:]
    private var betaByKey: [IdempotencyKey: BetaLink] = [:]
    private var photosByKey: [IdempotencyKey: RoutePhotoMetadata] = [:]
    private var correctionsByKey: [IdempotencyKey: RouteCorrectionReceipt] = [:]
    private var resetsByKey: [IdempotencyKey: ResetConfirmationReceipt] = [:]
    private var commentsByKey: [IdempotencyKey: BetaComment] = [:]
    private var reportsByKey: [IdempotencyKey: ContentReportReceipt] = [:]
    private let currentUserID: UserID
    private let managedGymIDs: Set<GymID>

    init(
        currentUserID: UserID = DevelopmentFixtures.currentUserID,
        managedGymIDs: Set<GymID> = []
    ) {
        self.currentUserID = currentUserID
        self.managedGymIDs = managedGymIDs
    }

    func addRoute(_ request: AddRouteRequest) throws -> ClimbingRoute {
        if let existing = routesByKey[request.idempotencyKey] { return existing }
        let colour = request.colour.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !colour.isEmpty,
              DevelopmentFixtures.wallZones.contains(where: {
                  $0.id == request.wallZoneID && $0.gymID == request.gymID
              }) else {
            throw RepositoryError.invalidInput
        }
        let route = ClimbingRoute(
            id: ClimbingRouteID(rawValue: request.idempotencyKey.rawValue.uuidString.lowercased()),
            gymID: request.gymID,
            wallZoneID: request.wallZoneID,
            colour: colour,
            terrain: request.terrain,
            styles: request.styles,
            subjectiveGrade: request.subjectiveGrade,
            officialGrade: nil,
            communityGradeSummary: CommunityGradeSummary(voteCount: 0, medianGrade: nil),
            resetDate: request.setDate,
            expectedArchiveDate: nil,
            isArchiveDateEstimated: false,
            lifecycle: .active,
            photoReference: nil,
            betaCount: 0,
            createdBy: currentUserID
        )
        routesByKey[request.idempotencyKey] = route
        return route
    }

    func updateRoute(_ routeID: ClimbingRouteID, request: AddRouteRequest) throws -> ClimbingRoute {
        let colour = request.colour.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !colour.isEmpty,
              DevelopmentFixtures.wallZones.contains(where: {
                  $0.id == request.wallZoneID && $0.gymID == request.gymID
              }) else {
            throw RepositoryError.invalidInput
        }
        let route = ClimbingRoute(
            id: routeID,
            gymID: request.gymID,
            wallZoneID: request.wallZoneID,
            colour: colour,
            terrain: request.terrain,
            styles: request.styles,
            subjectiveGrade: request.subjectiveGrade,
            officialGrade: nil,
            communityGradeSummary: CommunityGradeSummary(voteCount: 0, medianGrade: nil),
            resetDate: request.setDate,
            expectedArchiveDate: nil,
            isArchiveDateEstimated: false,
            lifecycle: .active,
            photoReference: nil,
            betaCount: 0,
            createdBy: currentUserID
        )
        return route
    }

    func createWallZone(_ request: AddWallZoneRequest) throws -> WallZone {
        if let existing = zonesByKey[request.idempotencyKey] { return existing }
        let name = request.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let location = request.locationDescription?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, DevelopmentFixtures.gyms.contains(where: { $0.id == request.gymID }) else {
            throw RepositoryError.invalidInput
        }
        let zone = WallZone(
            id: WallZoneID(rawValue: request.idempotencyKey.rawValue.uuidString.lowercased()),
            gymID: request.gymID,
            name: name,
            locationDescription: location ?? "",
            wallKind: request.wallKind,
            surfaceMaterial: request.surfaceMaterial,
            surfaceTexture: request.surfaceTexture,
            hasBoltHoles: request.hasBoltHoles,
            createdBy: currentUserID,
            latestResetDate: nil,
            routeCount: 0,
            betaCount: 0,
            availability: .active,
            sortOrder: max(0, request.sortOrder)
        )
        zonesByKey[request.idempotencyKey] = zone
        return zone
    }

    func updateWallZone(_ wallZoneID: WallZoneID, request: AddWallZoneRequest) throws -> WallZone {
        let name = request.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let location = request.locationDescription?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, DevelopmentFixtures.gyms.contains(where: { $0.id == request.gymID }) else {
            throw RepositoryError.invalidInput
        }
        let zone = WallZone(
            id: wallZoneID,
            gymID: request.gymID,
            name: name,
            locationDescription: location ?? "",
            wallKind: request.wallKind,
            surfaceMaterial: request.surfaceMaterial,
            surfaceTexture: request.surfaceTexture,
            hasBoltHoles: request.hasBoltHoles,
            createdBy: currentUserID,
            latestResetDate: nil,
            routeCount: 0,
            betaCount: 0,
            availability: .active,
            sortOrder: max(0, request.sortOrder)
        )
        return zone
    }

    func shareBetaLink(_ request: ShareBetaLinkRequest) throws -> BetaLink {
        if let existing = betaByKey[request.idempotencyKey] { return existing }
        guard DevelopmentFixtures.routes.contains(where: { $0.id == request.routeID }),
              Self.isHTTPS(request.publicURL), Self.isHTTPS(request.originalPostURL),
              !request.originalAuthor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RepositoryError.invalidExternalLink
        }
        let link = BetaLink(
            id: BetaLinkID(rawValue: request.idempotencyKey.rawValue.uuidString.lowercased()),
            routeID: request.routeID,
            sourceURL: request.publicURL,
            platform: request.platform,
            originalAuthor: request.originalAuthor,
            originalPostURL: request.originalPostURL,
            tags: request.tags,
            helpfulCount: 0,
            contributorHeightCentimetres: request.contributorHeightCentimetres,
            contributorArmSpanCentimetres: request.contributorArmSpanCentimetres,
            linkHealth: .healthy,
            moderationState: .visible,
            embedSupport: request.embedSupport,
            createdDate: Date()
        )
        betaByKey[request.idempotencyKey] = link
        return link
    }

    func addRoutePhoto(_ request: AddRoutePhotoRequest) throws -> RoutePhotoMetadata {
        if let existing = photosByKey[request.idempotencyKey] { return existing }
        guard DevelopmentFixtures.routes.contains(where: { $0.id == request.routeID }),
              Self.isHTTPS(request.publicImageURL),
              (request.width == nil && request.height == nil)
                || ((request.width ?? 0) > 0 && (request.height ?? 0) > 0) else {
            throw RepositoryError.invalidInput
        }
        let photo = RoutePhotoMetadata(
            id: request.idempotencyKey.rawValue,
            routeID: request.routeID,
            publicImageURL: request.publicImageURL,
            contributorID: currentUserID,
            isOfficialSource: false,
            createdAt: Date()
        )
        photosByKey[request.idempotencyKey] = photo
        return photo
    }

    func submitCorrection(_ request: SubmitRouteCorrectionRequest) throws -> RouteCorrectionReceipt {
        if let existing = correctionsByKey[request.idempotencyKey] { return existing }
        guard DevelopmentFixtures.routes.contains(where: { $0.id == request.routeID }),
              (request.explanation?.count ?? 0) <= 1_000 else {
            throw RepositoryError.invalidInput
        }
        let receipt = RouteCorrectionReceipt(
            id: request.idempotencyKey.rawValue,
            routeID: request.routeID,
            issue: request.issue,
            status: "open"
        )
        correctionsByKey[request.idempotencyKey] = receipt
        return receipt
    }

    func confirmReset(_ request: ConfirmResetRequest) throws -> ResetConfirmationReceipt {
        if let existing = resetsByKey[request.idempotencyKey] { return existing }
        guard DevelopmentFixtures.wallZones.contains(where: {
            $0.id == request.wallZoneID && $0.gymID == request.gymID
        }) else { throw RepositoryError.invalidInput }
        let isOfficial = managedGymIDs.contains(request.gymID)
        let receipt = ResetConfirmationReceipt(
            resetEventID: StableResetIdentifier.make(
                gymID: request.gymID,
                wallZoneID: request.wallZoneID,
                resetDate: request.resetDate
            ),
            state: isOfficial ? .confirmed : .pending,
            confirmationCount: isOfficial ? 0 : 1,
            isOfficial: isOfficial
        )
        resetsByKey[request.idempotencyKey] = receipt
        return receipt
    }

    func comments(betaLinkID: BetaLinkID) -> [BetaComment] {
        commentsByKey.values
            .filter { $0.betaLinkID == betaLinkID }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func addComment(_ request: AddBetaCommentRequest) throws -> BetaComment {
        if let existing = commentsByKey[request.idempotencyKey] { return existing }
        let body = request.body.trimmingCharacters(in: .whitespacesAndNewlines)
        let betaExists = DevelopmentFixtures.betaLinks.contains(where: { $0.id == request.betaLinkID })
            || betaByKey.values.contains(where: { $0.id == request.betaLinkID })
        guard betaExists, !body.isEmpty, body.count <= 200 else {
            throw RepositoryError.invalidInput
        }
        let comment = BetaComment(
            id: request.idempotencyKey.rawValue,
            betaLinkID: request.betaLinkID,
            authorID: currentUserID,
            officialGymID: request.officialGymID,
            body: body,
            createdAt: Date()
        )
        commentsByKey[request.idempotencyKey] = comment
        return comment
    }

    func reportContent(_ request: SubmitContentReportRequest) throws -> ContentReportReceipt {
        if let existing = reportsByKey[request.idempotencyKey] { return existing }
        guard !request.targetID.isEmpty, (request.details?.count ?? 0) <= 1_000 else {
            throw RepositoryError.invalidInput
        }
        let receipt = ContentReportReceipt(
            id: request.idempotencyKey.rawValue,
            targetType: request.targetType,
            targetID: request.targetID,
            category: request.category,
            isSevere: request.category.isSevere
        )
        reportsByKey[request.idempotencyKey] = receipt
        return receipt
    }

    private static func isHTTPS(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "https" && url.host != nil
    }
}

actor MockRelationshipRepository: RelationshipRepository {
    private let currentUserID: UserID
    private let profiles: [PublicUserProfile]
    private var following: Set<UserID> = []
    private var blocked: Set<UserID> = []
    private var completedMutations: Set<IdempotencyKey> = []

    init(
        currentUserID: UserID = DevelopmentFixtures.currentUserID,
        profiles: [PublicUserProfile] = [
            PublicUserProfile(
                userID: "fixture-contributor-taylor",
                username: "Taylor",
                avatarPath: nil,
                heightCentimetres: nil,
                armSpanCentimetres: nil,
                regularGrade: .v5,
                isTrustedContributor: true
            ),
            PublicUserProfile(
                userID: "fixture-contributor-morgan",
                username: "Morgan",
                avatarPath: nil,
                heightCentimetres: nil,
                armSpanCentimetres: nil,
                regularGrade: .v3,
                isTrustedContributor: false
            )
        ]
    ) {
        self.currentUserID = currentUserID
        self.profiles = profiles
    }

    func publicProfiles() -> [PublicUserProfile] {
        profiles.filter { !blocked.contains($0.userID) && $0.userID != currentUserID }
    }

    func blockedProfiles() -> [PublicUserProfile] {
        profiles.filter { blocked.contains($0.userID) && $0.userID != currentUserID }
    }

    func state(with userID: UserID) -> UserRelationshipState {
        UserRelationshipState(isFollowing: following.contains(userID), isBlocked: blocked.contains(userID))
    }

    func follow(userID: UserID, idempotencyKey: IdempotencyKey) throws {
        try validate(userID)
        guard completedMutations.insert(idempotencyKey).inserted else { return }
        guard !blocked.contains(userID) else { throw RepositoryError.invalidState }
        following.insert(userID)
    }

    func unfollow(userID: UserID, idempotencyKey: IdempotencyKey) throws {
        try validate(userID)
        guard completedMutations.insert(idempotencyKey).inserted else { return }
        following.remove(userID)
    }

    func block(userID: UserID, idempotencyKey: IdempotencyKey) throws {
        try validate(userID)
        guard completedMutations.insert(idempotencyKey).inserted else { return }
        blocked.insert(userID)
        following.remove(userID)
    }

    func unblock(userID: UserID, idempotencyKey: IdempotencyKey) throws {
        try validate(userID)
        guard completedMutations.insert(idempotencyKey).inserted else { return }
        blocked.remove(userID)
    }

    private func validate(_ userID: UserID) throws {
        guard userID != currentUserID else { throw RepositoryError.invalidInput }
    }
}

actor MockRoleRepository: RoleRepository {
    private let context: SessionRoleContext

    init(context: SessionRoleContext = .guest) {
        self.context = context
    }

    func sessionRoleContext() -> SessionRoleContext { context }
}

nonisolated enum StableResetIdentifier {
    static func make(gymID: GymID, wallZoneID: WallZoneID, resetDate: Date) -> UUID {
        var hash: UInt64 = 14_695_981_039_346_656_037
        let day = Calendar(identifier: .gregorian).startOfDay(for: resetDate).timeIntervalSince1970
        for byte in "\(gymID.rawValue)|\(wallZoneID.rawValue)|\(Int64(day))".utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        let second = hash &* 0x9E3779B185EBCA87
        let bytes: [UInt8] = (0..<8).map { UInt8(truncatingIfNeeded: hash >> ($0 * 8)) }
            + (0..<8).map { UInt8(truncatingIfNeeded: second >> ($0 * 8)) }
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
