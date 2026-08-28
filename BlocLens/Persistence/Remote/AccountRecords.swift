import Foundation

nonisolated struct LogbookEntryRecord: Codable, Equatable, Sendable {
    let id: UUID
    let userID: UUID
    let routeID: UUID
    let status: String
    let climbedAt: Date
    let attempts: Int?
    let privateNote: String?
    let predictedVGrade: Int?
    let clientCreatedAt: Date
    let clientIdempotencyKey: UUID
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, status, attempts
        case userID = "user_id"
        case routeID = "route_id"
        case climbedAt = "climbed_at"
        case privateNote = "private_note"
        case predictedVGrade = "predicted_v_grade"
        case clientCreatedAt = "client_created_at"
        case clientIdempotencyKey = "client_idempotency_key"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }

    func domain() throws -> LogbookEntry {
        guard deletedAt == nil else {
            throw RemoteMappingError.inconsistentData("Deleted Logbook rows are not active entries.")
        }
        let domainStatus: LogbookStatus
        switch status {
        case "want_to_try": domainStatus = .wantToTry
        case "projecting": domainStatus = .projecting
        case "sent": domainStatus = .sent
        case "flash": domainStatus = .flash
        default:
            throw RemoteMappingError.unsupportedValue(field: "logbook_entries.status", value: status)
        }

        return LogbookEntry(
            id: LogbookEntryID(rawValue: RemoteIdentifier.domainString(id)),
            userID: UserID(rawValue: RemoteIdentifier.domainString(userID)),
            routeID: ClimbingRouteID(rawValue: RemoteIdentifier.domainString(routeID)),
            status: domainStatus,
            date: climbedAt,
            attemptCount: attempts,
            privateNote: privateNote,
            predictedVGrade: try RemoteGrade.domain(
                predictedVGrade,
                field: "logbook_entries.predicted_v_grade"
            ),
            syncState: .synced,
            privacy: .privateByDefault
        )
    }

    init(
        domain: LogbookEntry,
        clientCreatedAt: Date,
        clientIdempotencyKey: UUID,
        serverCreatedAt: Date,
        serverUpdatedAt: Date
    ) throws {
        id = try RemoteIdentifier.uuid(from: domain.id, field: "logbook_entries.id")
        userID = try RemoteIdentifier.uuid(from: domain.userID, field: "logbook_entries.user_id")
        routeID = try RemoteIdentifier.uuid(from: domain.routeID, field: "logbook_entries.route_id")
        status = switch domain.status {
        case .wantToTry: "want_to_try"
        case .projecting: "projecting"
        case .sent: "sent"
        case .flash: "flash"
        }
        climbedAt = domain.date
        attempts = domain.attemptCount
        privateNote = domain.privateNote
        predictedVGrade = domain.predictedVGrade?.rawValue
        self.clientCreatedAt = clientCreatedAt
        self.clientIdempotencyKey = clientIdempotencyKey
        createdAt = serverCreatedAt
        updatedAt = serverUpdatedAt
        deletedAt = nil
    }
}

nonisolated struct UserProfileRecord: Codable, Equatable, Sendable {
    let id: UUID
    let username: String
    let avatarPath: String?
    let heightCM: Double?
    let armSpanCM: Double?
    let regularGrade: Int?
    let gradeSystem: String?
    let ydsGrade: String?
    let favouriteGymID: UUID?
    let isTrustedContributor: Bool
    let helpfulReceivedCount: Int
    let ageConfirmed16PlusAt: Date?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, username
        case avatarPath = "avatar_path"
        case heightCM = "height_cm"
        case armSpanCM = "arm_span_cm"
        case regularGrade = "regular_grade"
        case gradeSystem = "grade_system"
        case ydsGrade = "yds_grade"
        case favouriteGymID = "favourite_gym_id"
        case isTrustedContributor = "is_trusted_contributor"
        case helpfulReceivedCount = "helpful_received_count"
        case ageConfirmed16PlusAt = "age_confirmed_16_plus_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    func domain() throws -> UserProfile {
        let gradeSystem = gradeSystem.flatMap { GradeSystem(rawValue: $0) }
        let ydsGrade = ydsGrade.flatMap { YDSGrade(rawValue: $0) }
        return UserProfile(
            userID: UserID(rawValue: RemoteIdentifier.domainString(id)),
            username: username,
            heightCentimetres: heightCM,
            armSpanCentimetres: armSpanCM,
            regularGrade: try RemoteGrade.domain(regularGrade, field: "profiles.regular_grade"),
            gradeSystem: gradeSystem,
            ydsGrade: ydsGrade,
            favouriteGymID: favouriteGymID.map {
                GymID(rawValue: RemoteIdentifier.domainString($0))
            },
            isTrustedContributor: isTrustedContributor,
            helpfulVotes: max(0, helpfulReceivedCount)
        )
    }
}

nonisolated struct PublicProfileRecord: Codable, Equatable, Sendable {
    let id: UUID
    let username: String
    let avatarPath: String?
    let heightCM: Double?
    let armSpanCM: Double?
    let regularGrade: Int?
    let isTrustedContributor: Bool

    enum CodingKeys: String, CodingKey {
        case id, username
        case avatarPath = "avatar_path"
        case heightCM = "height_cm"
        case armSpanCM = "arm_span_cm"
        case regularGrade = "regular_grade"
        case isTrustedContributor = "is_trusted_contributor"
    }

    func domain() throws -> PublicUserProfile {
        PublicUserProfile(
            userID: UserID(rawValue: RemoteIdentifier.domainString(id)),
            username: username,
            avatarPath: avatarPath,
            heightCentimetres: heightCM,
            armSpanCentimetres: armSpanCM,
            regularGrade: try RemoteGrade.domain(regularGrade, field: "public_profiles.regular_grade"),
            isTrustedContributor: isTrustedContributor
        )
    }
}
