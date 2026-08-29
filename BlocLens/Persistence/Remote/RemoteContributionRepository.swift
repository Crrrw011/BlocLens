import Foundation

actor RemoteContributionRepository: ContributionRepository {
    private let dataSource: any RemoteContributionDataSource
    private var completedResetRequests: [IdempotencyKey: ResetConfirmationReceipt] = [:]

    init(dataSource: any RemoteContributionDataSource) {
        self.dataSource = dataSource
    }

    func addRoute(_ request: AddRouteRequest) async throws -> ClimbingRoute {
        let userID = try requireUser()
        let gymID = try uuid(request.gymID, field: "routes.gym_id")
        let zoneID = try uuid(request.wallZoneID, field: "routes.wall_zone_id")
        let colour = trimmed(request.colour)
        guard let colour, !colour.isEmpty else {
            throw RepositoryError.invalidInput
        }
        let official = try await mapped { try await dataSource.isGymOfficial(gymID: gymID) }
        let write = RouteContributionWrite(
            id: request.idempotencyKey.rawValue.uuidString,
            gymID: gymID.uuidString,
            wallZoneID: zoneID.uuidString,
            colour: colour,
            terrain: request.terrain.rawValue,
            styles: request.styles.map(\.rawValue),
            subjectiveGrade: request.subjectiveGrade?.rawValue,
            setDate: request.setDate.map(Self.timestamp),
            createdBy: userID.uuidString,
            isOfficialSource: official
        )
        let record: RouteRecord = try await idempotentInsert(
            id: request.idempotencyKey.rawValue,
            insert: { try await self.dataSource.insertRoute(write) },
            fetch: { try await self.dataSource.fetchRoute(id: $0) }
        )
        return try domainRoute(record)
    }

    func updateRoute(_ routeID: ClimbingRouteID, request: AddRouteRequest) async throws -> ClimbingRoute {
        let userID = try requireUser()
        let routeUUID = try uuid(routeID, field: "routes.id")
        let colour = trimmed(request.colour)
        guard let colour, !colour.isEmpty else {
            throw RepositoryError.invalidInput
        }
        let write = RouteUpdateWrite(
            colour: colour,
            terrain: request.terrain.rawValue,
            styles: request.styles.map(\.rawValue),
            subjectiveGrade: request.subjectiveGrade?.rawValue
        )
        let record: RouteRecord = try await mapped {
            try await self.dataSource.updateRoute(id: routeUUID, write: write)
        }
        return try domainRoute(record)
    }

    func createWallZone(_ request: AddWallZoneRequest) async throws -> WallZone {
        let userID = try requireUser()
        let gymID = try uuid(request.gymID, field: "wall_zones.gym_id")
        let name = trimmed(request.name)
        guard let name, !name.isEmpty else { throw RepositoryError.invalidInput }
        let location = trimmed(request.locationDescription)
        let zoneID = request.idempotencyKey.rawValue
        let write = WallZoneContributionWrite(
            id: zoneID.uuidString,
            gymID: gymID.uuidString,
            name: name,
            locationDescription: location,
            wallKind: request.wallKind.rawValue,
            surfaceMaterial: request.surfaceMaterial.rawValue,
            surfaceTexture: request.surfaceTexture.rawValue,
            hasBoltHoles: request.hasBoltHoles,
            displayOrder: max(0, request.sortOrder),
            createdBy: userID.uuidString
        )
        let record: WallZoneRecord = try await idempotentInsert(
            id: zoneID,
            insert: { try await self.dataSource.insertWallZone(write) },
            fetch: { try await self.dataSource.fetchWallZone(id: $0) }
        )
        return try domainZone(record)
    }

    func updateWallZone(_ wallZoneID: WallZoneID, request: AddWallZoneRequest) async throws -> WallZone {
        let userID = try requireUser()
        let zoneID = try uuid(wallZoneID, field: "wall_zones.id")
        let name = trimmed(request.name)
        guard let name, !name.isEmpty else { throw RepositoryError.invalidInput }
        let location = trimmed(request.locationDescription)
        let write = WallZoneUpdateWrite(
            name: name,
            locationDescription: location,
            wallKind: request.wallKind.rawValue,
            surfaceMaterial: request.surfaceMaterial.rawValue,
            surfaceTexture: request.surfaceTexture.rawValue,
            hasBoltHoles: request.hasBoltHoles,
            displayOrder: max(0, request.sortOrder)
        )
        let record: WallZoneRecord = try await mapped {
            try await self.dataSource.updateWallZone(id: zoneID, write: write)
        }
        return try domainZone(record)
    }

    func shareBetaLink(_ request: ShareBetaLinkRequest) async throws -> BetaLink {
        let userID = try requireUser()
        guard isHTTPS(request.publicURL), isHTTPS(request.originalPostURL),
              let author = trimmed(request.originalAuthor), author.count <= 120 else {
            throw RepositoryError.invalidExternalLink
        }
        let routeID = try uuid(request.routeID, field: "beta_links.route_id")
        let write = BetaContributionWrite(
            id: request.idempotencyKey.rawValue.uuidString,
            routeID: routeID.uuidString,
            publicURL: request.publicURL.absoluteString,
            platform: databasePlatform(request.platform),
            originalAuthorDisplayName: author,
            originalPostURL: request.originalPostURL.absoluteString,
            submittedBy: userID.uuidString,
            tags: request.tags.map(databaseTag),
            submitterHeightCM: request.contributorHeightCentimetres,
            submitterArmSpanCM: request.contributorArmSpanCentimetres,
            embedCapability: request.embedSupport == .supported ? "supported" : "source_platform_only",
            isOfficialSource: false
        )
        let record: BetaLinkRecord = try await idempotentInsert(
            id: request.idempotencyKey.rawValue,
            insert: { try await self.dataSource.insertBetaLink(write) },
            fetch: { try await self.dataSource.fetchBetaLink(id: $0) }
        )
        return try domain(record)
    }

    func addRoutePhoto(_ request: AddRoutePhotoRequest) async throws -> RoutePhotoMetadata {
        let userID = try requireUser()
        guard isHTTPS(request.publicImageURL),
              (request.width == nil && request.height == nil)
                || ((request.width ?? 0) > 0 && (request.height ?? 0) > 0) else {
            throw RepositoryError.invalidInput
        }
        let routeID = try uuid(request.routeID, field: "route_photos.route_id")
        let write = RoutePhotoContributionWrite(
            id: request.idempotencyKey.rawValue.uuidString,
            routeID: routeID.uuidString,
            storagePath: request.publicImageURL.absoluteString,
            uploadedBy: userID.uuidString,
            isOfficialSource: false,
            width: request.width,
            height: request.height
        )
        let record: RoutePhotoRecord = try await idempotentInsert(
            id: request.idempotencyKey.rawValue,
            insert: { try await self.dataSource.insertPhoto(write) },
            fetch: { try await self.dataSource.fetchPhoto(id: $0) }
        )
        return try domain(record)
    }

    func submitCorrection(_ request: SubmitRouteCorrectionRequest) async throws -> RouteCorrectionReceipt {
        let userID = try requireUser()
        guard (request.explanation?.count ?? 0) <= 1_000 else { throw RepositoryError.invalidInput }
        let routeID = try uuid(request.routeID, field: "route_corrections.route_id")
        let write = RouteCorrectionWrite(
            id: request.idempotencyKey.rawValue.uuidString,
            routeID: routeID.uuidString,
            submittedBy: userID.uuidString,
            issueKey: request.issue.rawValue,
            proposedValue: trimmed(request.proposedValue),
            explanation: trimmed(request.explanation)
        )
        let record: RouteCorrectionRecord = try await idempotentInsert(
            id: request.idempotencyKey.rawValue,
            insert: { try await self.dataSource.insertCorrection(write) },
            fetch: { try await self.dataSource.fetchCorrection(id: $0) }
        )
        return try domain(record)
    }

    func confirmReset(_ request: ConfirmResetRequest) async throws -> ResetConfirmationReceipt {
        if let completed = completedResetRequests[request.idempotencyKey] { return completed }
        let userID = try requireUser()
        let gymID = try uuid(request.gymID, field: "reset_events.gym_id")
        let zoneID = try uuid(request.wallZoneID, field: "reset_events.wall_zone_id")
        let eventID = StableResetIdentifier.make(
            gymID: request.gymID,
            wallZoneID: request.wallZoneID,
            resetDate: request.resetDate
        )
        let official = try await mapped { try await dataSource.isGymOfficial(gymID: gymID) }
        let write = ResetEventWrite(
            id: eventID.uuidString,
            gymID: gymID.uuidString,
            wallZoneID: zoneID.uuidString,
            resetDate: Self.timestamp(request.resetDate),
            source: official ? "official" : "community_confirmed",
            state: official ? "confirmed" : "pending",
            createdBy: userID.uuidString,
            isOfficial: official
        )
        do {
            try await dataSource.insertResetEvent(write)
        } catch {
            guard RemoteErrorMapping.map(error) == .conflict else { throw RemoteErrorMapping.map(error) }
        }
        if !official {
            do {
                try await dataSource.insertResetConfirmation(eventID: eventID, userID: userID)
            } catch {
                guard RemoteErrorMapping.map(error) == .conflict else { throw RemoteErrorMapping.map(error) }
            }
        }
        guard let record = try await mapped({ try await dataSource.fetchResetEvent(id: eventID) }) else {
            throw RepositoryError.notFound
        }
        let receipt = try record.domain()
        completedResetRequests[request.idempotencyKey] = receipt
        return receipt
    }

    func comments(betaLinkID: BetaLinkID) async throws -> [BetaComment] {
        let userID = try requireUser()
        let betaID = try uuid(betaLinkID, field: "beta_comments.beta_link_id")
        let blocked = Set(try await mapped { try await dataSource.fetchBlockedUserIDs(userID: userID) })
        let records = try await mapped { try await dataSource.fetchComments(betaLinkID: betaID) }
        return try records.filter { record in
            guard let authorID = record.authorID else { return true }
            return !blocked.contains(authorID)
        }.map(domain)
    }

    func addComment(_ request: AddBetaCommentRequest) async throws -> BetaComment {
        let userID = try requireUser()
        guard let body = trimmed(request.body), body.count <= 200 else { throw RepositoryError.invalidInput }
        let write = BetaCommentWrite(
            id: request.idempotencyKey.rawValue.uuidString,
            betaLinkID: try uuid(request.betaLinkID, field: "beta_comments.beta_link_id").uuidString,
            authorID: userID.uuidString,
            officialGymID: try request.officialGymID.map { try uuid($0, field: "beta_comments.official_gym_id").uuidString },
            body: body
        )
        let record: BetaCommentRecord = try await idempotentInsert(
            id: request.idempotencyKey.rawValue,
            insert: { try await self.dataSource.insertComment(write) },
            fetch: { try await self.dataSource.fetchComment(id: $0) }
        )
        return try domain(record)
    }

    func reportContent(_ request: SubmitContentReportRequest) async throws -> ContentReportReceipt {
        let userID = try requireUser()
        guard (request.details?.count ?? 0) <= 1_000,
              let targetID = UUID(uuidString: request.targetID) else {
            throw RepositoryError.invalidInput
        }
        let write = ContentReportWrite(
            id: request.idempotencyKey.rawValue.uuidString,
            targetType: request.targetType.rawValue,
            targetID: targetID.uuidString,
            category: request.category.rawValue,
            reporterID: userID.uuidString,
            details: trimmed(request.details)
        )
        let record: ContentReportRecord = try await idempotentInsert(
            id: request.idempotencyKey.rawValue,
            insert: { try await self.dataSource.insertReport(write) },
            fetch: { try await self.dataSource.fetchReport(id: $0) }
        )
        return try domain(record)
    }

    func submitFeedback(_ request: SubmitFeedbackRequest) async throws -> FeedbackReceipt {
        let userID = dataSource.currentUserID()
        let message = trimmed(request.message)
        guard let message, !message.isEmpty, message.count <= 4_000 else {
            throw RepositoryError.invalidInput
        }
        let pageID = trimmed(request.currentPageID)
        let write = FeedbackWrite(
            id: request.idempotencyKey.rawValue.uuidString,
            userID: userID?.uuidString,
            category: request.category.rawValue,
            message: message,
            currentPageID: pageID
        )
        let record: FeedbackRecord = try await idempotentInsert(
            id: request.idempotencyKey.rawValue,
            insert: { try await self.dataSource.insertFeedback(write) },
            fetch: { try await self.dataSource.fetchFeedback(id: $0) }
        )
        return try domain(record)
    }

    func submitGym(_ request: SubmitGymRequest) async throws -> GymSubmissionReceipt {
        let userID = try requireUser()
        let name = trimmed(request.name)
        guard let name, !name.isEmpty, !request.googlePlaceID.isEmpty else {
            throw RepositoryError.invalidInput
        }
        let suburb = trimmed(request.suburb) ?? ""
        let state = trimmed(request.state) ?? ""
        let address = trimmed(request.streetAddress)
        let postcode = trimmed(request.postcode)
        let write = GymSubmissionWrite(
            id: request.idempotencyKey.rawValue.uuidString,
            googlePlaceID: request.googlePlaceID,
            name: name,
            streetAddress: address,
            suburb: suburb,
            state: state,
            postcode: postcode,
            latitude: request.latitude,
            longitude: request.longitude,
            submittedBy: userID.uuidString
        )
        let record: GymSubmissionRecord = try await idempotentInsert(
            id: request.idempotencyKey.rawValue,
            insert: { try await self.dataSource.insertGymSubmission(write) },
            fetch: { try await self.dataSource.fetchGymSubmission(id: $0) }
        )
        return try domain(record)
    }

    private func requireUser() throws -> UUID {
        guard let id = dataSource.currentUserID() else { throw RepositoryError.unauthenticated }
        return id
    }

    private func idempotentInsert<Record: Sendable>(
        id: UUID,
        insert: () async throws -> Record,
        fetch: (UUID) async throws -> Record
    ) async throws -> Record {
        do { return try await insert() }
        catch is CancellationError { throw CancellationError() }
        catch {
            guard RemoteErrorMapping.map(error) == .conflict else { throw RemoteErrorMapping.map(error) }
            do {
                return try await mapped { try await fetch(id) }
            } catch RepositoryError.notFound {
                // A different primary key may have reached a business-unique constraint
                // (for example one open correction per user and issue). Preserve conflict
                // semantics rather than reporting that the requested new ID was missing.
                throw RepositoryError.conflict
            }
        }
    }

    private func mapped<Value: Sendable>(_ operation: () async throws -> Value) async throws -> Value {
        do { return try await operation() }
        catch is CancellationError { throw CancellationError() }
        catch let error as RepositoryError { throw error }
        catch { throw RemoteErrorMapping.map(error) }
    }

    private func uuid<Tag>(_ id: EntityID<Tag>, field: String) throws -> UUID {
        do { return try RemoteIdentifier.uuid(from: id, field: field) }
        catch { throw RepositoryError.invalidInput }
    }

    private func domainRoute(_ record: RouteRecord) throws -> ClimbingRoute {
        do {
            return try record.domain(
                communityGrade: CommunityGradeRecord(
                    routeID: record.id,
                    voteCount: 0,
                    isDisplayEligible: false,
                    medianVGrade: nil
                )
            )
        } catch { throw RepositoryError.decodingFailure }
    }

    private func domain(_ record: BetaLinkRecord) throws -> BetaLink {
        do { return try record.domain() } catch { throw RepositoryError.decodingFailure }
    }
    private func domainZone(_ record: WallZoneRecord) throws -> WallZone {
        do { return try record.domain() } catch { throw RepositoryError.decodingFailure }
    }
    private func domain(_ record: RoutePhotoRecord) throws -> RoutePhotoMetadata {
        do { return try record.domain() } catch { throw RepositoryError.decodingFailure }
    }
    private func domain(_ record: RouteCorrectionRecord) throws -> RouteCorrectionReceipt {
        do { return try record.domain() } catch { throw RepositoryError.decodingFailure }
    }
    private func domain(_ record: BetaCommentRecord) throws -> BetaComment {
        do { return try record.domain() } catch { throw RepositoryError.decodingFailure }
    }
    private func domain(_ record: ContentReportRecord) throws -> ContentReportReceipt {
        do { return try record.domain() } catch { throw RepositoryError.decodingFailure }
    }

    private func domain(_ record: FeedbackRecord) throws -> FeedbackReceipt {
        do { return try record.domain() } catch { throw RepositoryError.decodingFailure }
    }

    private func domain(_ record: GymSubmissionRecord) throws -> GymSubmissionReceipt {
        do { return try record.domain() } catch { throw RepositoryError.decodingFailure }
    }

    private func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let result = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }

    private func isHTTPS(_ url: URL) -> Bool { url.scheme?.lowercased() == "https" && url.host != nil }

    private static func timestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private func databasePlatform(_ platform: BetaPlatform) -> String { platform.rawValue }
    private func databaseTag(_ tag: BetaTag) -> String {
        switch tag {
        case .fullSolution: "full_solution"
        case .crux: "crux"
        case .staticMovement: "static"
        case .dynamicMovement: "dynamic"
        case .shortPersonBeta: "short_climber"
        case .tallLongReachBeta: "tall_climber"
        }
    }
}
