import Foundation

nonisolated struct PublicUserProfile: Equatable, Sendable {
    let userID: UserID
    let username: String
    let avatarPath: String?
    let heightCentimetres: Double?
    let armSpanCentimetres: Double?
    let regularGrade: VGrade?
    let isTrustedContributor: Bool
}
