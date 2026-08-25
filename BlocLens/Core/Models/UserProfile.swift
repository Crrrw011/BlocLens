import Foundation

nonisolated struct UserProfile: Codable, Equatable, Sendable {
    let userID: UserID
    let username: String
    let heightCentimetres: Double?
    let armSpanCentimetres: Double?
    let regularGrade: VGrade?
    let favouriteGymID: GymID?
    let isTrustedContributor: Bool
    let helpfulVotes: Int
}

nonisolated enum AuthenticationState: Equatable, Sendable {
    case guest
    case signedIn(UserProfile)

    var profile: UserProfile? {
        guard case .signedIn(let profile) = self else { return nil }
        return profile
    }

    var isSignedIn: Bool { profile != nil }
}

nonisolated enum ProtectedIntent: Equatable, Sendable {
    case revealBeta(routeID: ClimbingRouteID)
    case saveLogbook(routeID: ClimbingRouteID, status: LogbookStatus)
    case add(AddAction)
    case helpful(betaID: BetaLinkID)
    case account
}

nonisolated enum AppearancePreference: String, CaseIterable, Sendable {
    case system
    case light
    case dark
}
