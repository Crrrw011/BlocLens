import Foundation

nonisolated struct RoutePhotoRecord: Codable, Equatable, Sendable {
    let id: UUID
    let routeID: UUID
    let storagePath: String
    let uploadedBy: UUID?
    let isOfficialSource: Bool
    let moderationStatus: String
    let createdAt: Date
    let deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case routeID = "route_id"
        case storagePath = "storage_path"
        case uploadedBy = "uploaded_by"
        case isOfficialSource = "is_official_source"
        case moderationStatus = "moderation_status"
        case createdAt = "created_at"
        case deletedAt = "deleted_at"
    }

    func domain() throws -> RoutePhotoMetadata {
        guard deletedAt == nil, moderationStatus == "visible",
              let uploadedBy,
              let url = URL(string: storagePath), url.scheme?.lowercased() == "https" else {
            throw RemoteMappingError.inconsistentData("Route photo metadata is not publicly usable.")
        }
        return RoutePhotoMetadata(
            id: id,
            routeID: ClimbingRouteID(rawValue: RemoteIdentifier.domainString(routeID)),
            publicImageURL: url,
            contributorID: UserID(rawValue: RemoteIdentifier.domainString(uploadedBy)),
            isOfficialSource: isOfficialSource,
            createdAt: createdAt
        )
    }
}

nonisolated struct RouteCorrectionRecord: Codable, Equatable, Sendable {
    let id: UUID
    let routeID: UUID
    let issueKey: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case id, status
        case routeID = "route_id"
        case issueKey = "issue_key"
    }

    func domain() throws -> RouteCorrectionReceipt {
        guard let issue = RouteCorrectionIssue(rawValue: issueKey) else {
            throw RemoteMappingError.unsupportedValue(field: "route_corrections.issue_key", value: issueKey)
        }
        return RouteCorrectionReceipt(
            id: id,
            routeID: ClimbingRouteID(rawValue: RemoteIdentifier.domainString(routeID)),
            issue: issue,
            status: status
        )
    }
}

nonisolated struct ResetEventRecord: Codable, Equatable, Sendable {
    let id: UUID
    let state: String
    let confirmationCount: Int
    let isOfficial: Bool

    enum CodingKeys: String, CodingKey {
        case id, state
        case confirmationCount = "confirmation_count"
        case isOfficial = "is_official"
    }

    func domain() throws -> ResetConfirmationReceipt {
        guard let state = ResetConfirmationState(rawValue: state) else {
            throw RemoteMappingError.unsupportedValue(field: "reset_events.state", value: self.state)
        }
        return ResetConfirmationReceipt(
            resetEventID: id,
            state: state,
            confirmationCount: max(0, confirmationCount),
            isOfficial: isOfficial
        )
    }
}

nonisolated struct BetaCommentRecord: Codable, Equatable, Sendable {
    let id: UUID
    let betaLinkID: UUID
    let authorID: UUID?
    let officialGymID: UUID?
    let body: String
    let moderationStatus: String
    let createdAt: Date
    let deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, body
        case betaLinkID = "beta_link_id"
        case authorID = "author_id"
        case officialGymID = "official_gym_id"
        case moderationStatus = "moderation_status"
        case createdAt = "created_at"
        case deletedAt = "deleted_at"
    }

    func domain() throws -> BetaComment {
        guard moderationStatus == "visible", deletedAt == nil, let authorID else {
            throw RemoteMappingError.inconsistentData("Comment is not publicly visible.")
        }
        return BetaComment(
            id: id,
            betaLinkID: BetaLinkID(rawValue: RemoteIdentifier.domainString(betaLinkID)),
            authorID: UserID(rawValue: RemoteIdentifier.domainString(authorID)),
            officialGymID: officialGymID.map { GymID(rawValue: RemoteIdentifier.domainString($0)) },
            body: body,
            createdAt: createdAt
        )
    }
}

nonisolated struct ContentReportRecord: Codable, Equatable, Sendable {
    let id: UUID
    let targetType: String
    let targetID: UUID
    let category: String
    let isSevere: Bool

    enum CodingKeys: String, CodingKey {
        case id, category
        case targetType = "target_type"
        case targetID = "target_id"
        case isSevere = "is_severe"
    }

    func domain() throws -> ContentReportReceipt {
        guard let targetType = ReportableContentType(rawValue: targetType),
              let category = ContentReportCategory(rawValue: category) else {
            throw RemoteMappingError.unsupportedValue(field: "content_reports", value: "\(self.targetType)/\(self.category)")
        }
        return ContentReportReceipt(
            id: id,
            targetType: targetType,
            targetID: targetID.uuidString.lowercased(),
            category: category,
            isSevere: isSevere
        )
    }
}

nonisolated struct FeedbackRecord: Codable, Equatable, Sendable {
    let id: UUID
    let category: String

    enum CodingKeys: String, CodingKey {
        case id, category
    }

    func domain() throws -> FeedbackReceipt {
        guard let category = FeedbackCategory(rawValue: category) else {
            throw RemoteMappingError.unsupportedValue(field: "app_feedback.category", value: category)
        }
        return FeedbackReceipt(id: id, category: category)
    }
}

nonisolated struct GymSubmissionRecord: Codable, Equatable, Sendable {
    let id: UUID
    let status: String

    enum CodingKeys: String, CodingKey {
        case id, status
    }

    func domain() throws -> GymSubmissionReceipt {
        return GymSubmissionReceipt(id: id, status: status)
    }
}

nonisolated struct GymScopeRecord: Codable, Equatable, Sendable {
    let gymID: UUID

    enum CodingKeys: String, CodingKey {
        case gymID = "gym_id"
    }
}