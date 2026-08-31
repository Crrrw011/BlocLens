import Foundation

struct ProfileEditState {
    var heightCentimetres: Double?
    var armSpanCentimetres: Double?
    var hasHeight: Bool
    var hasArmSpan: Bool
    var gradeSystem: GradeSystem?
    var vGrade: VGrade?
    var ydsGrade: YDSGrade?
    var isNotSureYet: Bool
    var favouriteGymID: GymID?

    private static let defaultHeight: Double = 170
    private static let defaultArmSpan: Double = 170

    init(profile: UserProfile?) {
        if let profile {
            heightCentimetres = profile.heightCentimetres
            armSpanCentimetres = profile.armSpanCentimetres
            hasHeight = profile.heightCentimetres != nil
            hasArmSpan = profile.armSpanCentimetres != nil
            gradeSystem = profile.gradeSystem
            vGrade = profile.regularGrade
            ydsGrade = profile.ydsGrade
            isNotSureYet = profile.regularGrade == nil && profile.ydsGrade == nil && profile.gradeSystem == nil
            favouriteGymID = profile.favouriteGymID
        } else {
            heightCentimetres = Self.defaultHeight
            armSpanCentimetres = Self.defaultArmSpan
            hasHeight = true
            hasArmSpan = true
            gradeSystem = .vScale
            vGrade = nil
            ydsGrade = nil
            isNotSureYet = true
            favouriteGymID = nil
        }
    }

    var isGradeSet: Bool {
        guard let gradeSystem else { return false }
        switch gradeSystem {
        case .vScale: return vGrade != nil
        case .yds: return ydsGrade != nil
        }
    }

    func toSavedGrade() -> (regularGrade: VGrade?, gradeSystem: GradeSystem?, ydsGrade: YDSGrade?) {
        if isNotSureYet { return (nil, nil, nil) }
        let useGrade = gradeSystem != nil && isGradeSet
        return (
            regularGrade: useGrade && gradeSystem == .vScale ? vGrade : nil,
            gradeSystem: useGrade ? gradeSystem : nil,
            ydsGrade: useGrade && gradeSystem == .yds ? ydsGrade : nil
        )
    }
}
