import Foundation

nonisolated enum NotificationCategory: String, CaseIterable, Codable, Equatable, Sendable {
    case projectRemoval = "project_removal"
    case gymReset = "gym_reset"
    case newBetaForProject = "new_beta_for_project"
    case followedContributorBeta = "followed_contributor_beta"
}

nonisolated struct NotificationPreference: Equatable, Sendable {
    let category: NotificationCategory
    let isEnabled: Bool
}

nonisolated struct UserRelationshipState: Equatable, Sendable {
    let isFollowing: Bool
    let isBlocked: Bool
}

nonisolated enum SessionAppRole: String, Equatable, Sendable {
    case user
    case trustedContributor
    case moderator
    case administrator
}

nonisolated struct SessionRoleContext: Equatable, Sendable {
    let appRole: SessionAppRole
    let managedGymIDs: Set<GymID>

    static let guest = SessionRoleContext(appRole: .user, managedGymIDs: [])

    var isTrustedContributor: Bool {
        appRole == .trustedContributor || appRole == .moderator || appRole == .administrator
    }

    var isModerator: Bool {
        appRole == .moderator || appRole == .administrator
    }

    var isAdministrator: Bool {
        appRole == .administrator
    }

    func manages(gymID: GymID) -> Bool {
        managedGymIDs.contains(gymID)
    }
}
