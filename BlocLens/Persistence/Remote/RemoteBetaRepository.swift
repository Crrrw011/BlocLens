import Foundation

actor RemoteBetaRepository: BetaRepository {
    private let dataSource: any RemoteBetaDataSource

    init(dataSource: any RemoteBetaDataSource) {
        self.dataSource = dataSource
    }

    func betaLinks(routeID: ClimbingRouteID, viewer: BetaViewerProfile?) async throws -> [BetaLink] {
        let links = try await betaMetadata(for: routeID)
        return BetaRanker.visibleLinks(links, viewer: viewer)
    }

    func brokenBetaLinks(routeID: ClimbingRouteID) async throws -> [BetaLink] {
        let links = try await betaMetadata(for: routeID)
        return links.filter { $0.linkHealth == .broken && $0.moderationState == .visible }
    }

    func validateExternalURL(_ url: URL) async -> Bool {
        BetaLink.isValidExternalURL(url)
    }

    func betaMetadata(for routeID: ClimbingRouteID) async throws -> [BetaLink] {
        guard let userID = dataSource.currentUserID() else {
            throw RepositoryError.unauthenticated
        }
        do {
            let routeUUID = try Self.uuid(routeID)
            let blockedIDs = Set(try await dataSource.fetchBlockedUserIDs(blockerID: userID))
            let records = try await dataSource.fetchBetaLinks(routeID: routeUUID)
            let visible = records.filter { record in
                guard let submitter = record.submittedBy else { return true }
                return !blockedIDs.contains(submitter)
            }
            return try visible.map { try Self.domain($0) }
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as RepositoryError {
            throw error
        } catch {
            throw RemoteErrorMapping.map(error)
        }
    }

    func revealBeta(_ betaID: BetaLinkID) async throws -> BetaLink {
        guard dataSource.currentUserID() != nil else {
            throw RepositoryError.unauthenticated
        }
        do {
            let record = try await dataSource.fetchBetaLink(betaID: try Self.uuid(betaID))
            return try Self.domain(record)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as RepositoryError {
            throw error
        } catch {
            throw RemoteErrorMapping.map(error)
        }
    }

    func markHelpful(_ betaID: BetaLinkID) async throws {
        guard let userID = dataSource.currentUserID() else {
            throw RepositoryError.unauthenticated
        }
        do {
            try await dataSource.insertHelpfulVote(betaID: try Self.uuid(betaID), userID: userID)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw RemoteErrorMapping.map(error)
        }
    }

    func reportBeta(_ betaID: BetaLinkID, reason: ReportReason) async throws {
        guard let userID = dataSource.currentUserID() else {
            throw RepositoryError.unauthenticated
        }
        do {
            try await dataSource.insertReport(
                betaID: try Self.uuid(betaID),
                reporterID: userID,
                category: reason.databaseValue
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw RemoteErrorMapping.map(error)
        }
    }

    func communityGradeVote(routeID: ClimbingRouteID, grade: VGrade) async throws {
        guard grade != .unknown else {
            throw RepositoryError.invalidInput
        }
        guard let userID = dataSource.currentUserID() else {
            throw RepositoryError.unauthenticated
        }
        do {
            let routeUUID = try Self.uuid(routeID)
            let hasAttempt = try await dataSource.hasValidAttempt(routeID: routeUUID)
            guard hasAttempt else {
                throw RepositoryError.invalidState
            }
            if try await dataSource.fetchMyGradeVote(routeID: routeUUID, userID: userID) == nil {
                try await dataSource.insertGradeVote(routeID: routeUUID, userID: userID, grade: grade.rawValue)
            } else {
                try await dataSource.updateGradeVote(routeID: routeUUID, userID: userID, grade: grade.rawValue)
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as RepositoryError {
            throw error
        } catch {
            throw RemoteErrorMapping.map(error)
        }
    }

    func myGradeVote(for routeID: ClimbingRouteID) async throws -> VGrade? {
        guard let userID = dataSource.currentUserID() else {
            throw RepositoryError.unauthenticated
        }
        do {
            let raw = try await dataSource.fetchMyGradeVote(
                routeID: try Self.uuid(routeID),
                userID: userID
            )
            return raw.flatMap(VGrade.init(rawValue:))
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as RepositoryError {
            throw error
        } catch {
            throw RemoteErrorMapping.map(error)
        }
    }

    func hasConfirmedSafety() async -> Bool {
        dataSource.hasConfirmedSafety()
    }

    func confirmSafety() async throws {
        guard dataSource.currentUserID() != nil else {
            throw RepositoryError.unauthenticated
        }
        do {
            try await dataSource.confirmSafety()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw RemoteErrorMapping.map(error)
        }
    }

    private static func uuid<Tag>(_ id: EntityID<Tag>) throws -> UUID {
        guard let uuid = UUID(uuidString: id.rawValue) else {
            throw RepositoryError.notFound
        }
        return uuid
    }

    private static func domain(_ record: BetaLinkRecord) throws -> BetaLink {
        do {
            return try record.domain()
        } catch {
            throw RepositoryError.decodingFailure
        }
    }
}
