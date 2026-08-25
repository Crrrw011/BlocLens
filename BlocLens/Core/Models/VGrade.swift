import Foundation

nonisolated enum VGrade: Int, CaseIterable, Codable, Equatable, Hashable, Sendable, Comparable {
    case unknown = -2
    case vb = -1
    case v0 = 0
    case v1
    case v2
    case v3
    case v4
    case v5
    case v6
    case v7
    case v8
    case v9
    case v10
    case v11
    case v12
    case v13
    case v14
    case v15
    case v16
    case v17

    var displayName: String {
        switch self {
        case .unknown: "Unknown"
        case .vb: "VB"
        default: "V\(rawValue)"
        }
    }

    init?(displayName: String) {
        let normalised = displayName.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if normalised == "UNKNOWN" {
            self = .unknown
        } else if normalised == "VB" {
            self = .vb
        } else if normalised.hasPrefix("V"),
                  let value = Int(normalised.dropFirst()),
                  let grade = VGrade(rawValue: value),
                  grade != .unknown,
                  grade != .vb {
            self = grade
        } else {
            return nil
        }
    }

    static func < (lhs: VGrade, rhs: VGrade) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }

    private var sortOrder: Int {
        self == .unknown ? Int.max : rawValue
    }
}

nonisolated enum GradeBand: String, CaseIterable, Codable, Equatable, Sendable {
    case all
    case v0ToV2
    case v3ToV5
    case v6Plus

    func contains(_ grade: VGrade?) -> Bool {
        guard self != .all else { return true }
        guard let grade, grade != .unknown else { return false }
        switch self {
        case .all: return true
        case .v0ToV2: return grade == .vb || (.v0 ... .v2).contains(grade)
        case .v3ToV5: return (.v3 ... .v5).contains(grade)
        case .v6Plus: return grade >= .v6
        }
    }
}
