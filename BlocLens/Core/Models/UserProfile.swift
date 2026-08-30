import Foundation

nonisolated struct UserProfile: Codable, Equatable, Sendable {
    let userID: UserID
    let username: String
    let heightCentimetres: Double?
    let armSpanCentimetres: Double?
    let regularGrade: VGrade?
    let gradeSystem: GradeSystem?
    let ydsGrade: YDSGrade?
    let favouriteGymID: GymID?
    let isTrustedContributor: Bool
    let helpfulVotes: Int
}

nonisolated enum AuthenticationState: Equatable, Sendable {
    case guest
    case authenticating
    case profileSetup(UserProfile)
    case ageGated
    case signedIn(UserProfile)
    case emailConfirmationRequired
    case error(RepositoryError)

    var profile: UserProfile? {
        switch self {
        case .signedIn(let profile), .profileSetup(let profile):
            return profile
        default:
            return nil
        }
    }

    var isSignedIn: Bool { profile != nil }

    var isProfileSetup: Bool {
        if case .profileSetup = self { return true }
        return false
    }

    var isEmailConfirmationRequired: Bool {
        if case .emailConfirmationRequired = self { return true }
        return false
    }
}

nonisolated enum ProtectedIntent: Equatable, Sendable {
    case revealBeta(routeID: ClimbingRouteID)
    case saveLogbook(routeID: ClimbingRouteID, status: LogbookStatus)
    case add(AddAction)
    case addRouteInZone(wallZoneID: WallZoneID)
    case helpful(betaID: BetaLinkID)
    case account
}

nonisolated enum AppearancePreference: String, CaseIterable, Sendable {
    case system
    case light
    case dark
}

nonisolated enum LanguagePreference: String, CaseIterable, Sendable {
    case system
    case englishAustralian
    case korean
    case simplifiedChinese

    var localeIdentifier: String? {
        switch self {
        case .system: nil
        case .englishAustralian: "en-AU"
        case .korean: "ko"
        case .simplifiedChinese: "zh-Hans"
        }
    }
}
