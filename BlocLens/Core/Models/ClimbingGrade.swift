import Foundation

nonisolated enum GradeSystem: String, Codable, CaseIterable, Equatable, Sendable {
    case vScale = "V"
    case yds = "YDS"
}

nonisolated enum YDSGrade: String, Codable, CaseIterable, Equatable, Sendable, Comparable {
    case fiveFive = "5.5"
    case fiveSix = "5.6"
    case fiveSeven = "5.7"
    case fiveEight = "5.8"
    case fiveNine = "5.9"
    case fiveTenA = "5.10a"
    case fiveTenB = "5.10b"
    case fiveTenC = "5.10c"
    case fiveTenD = "5.10d"
    case fiveElevenA = "5.11a"
    case fiveElevenB = "5.11b"
    case fiveElevenC = "5.11c"
    case fiveElevenD = "5.11d"
    case fiveTwelveA = "5.12a"
    case fiveTwelveB = "5.12b"
    case fiveTwelveC = "5.12c"
    case fiveTwelveD = "5.12d"
    case fiveThirteenA = "5.13a"
    case fiveThirteenB = "5.13b"
    case fiveThirteenC = "5.13c"
    case fiveThirteenD = "5.13d"
    case fiveFourteenA = "5.14a"
    case fiveFourteenB = "5.14b"
    case fiveFourteenC = "5.14c"
    case fiveFourteenD = "5.14d"
    case fiveFifteenA = "5.15a"
    case fiveFifteenB = "5.15b"
    case fiveFifteenC = "5.15c"
    case fiveFifteenD = "5.15d"

    var displayName: String { rawValue }

    private var sortKey: Double {
        let parts = rawValue.dropFirst(2).split(whereSeparator: { $0 == "a" || $0 == "b" || $0 == "c" || $0 == "d" })
        guard let major = Double(parts.first ?? "") else { return 0 }
        let suffix: Double
        if rawValue.hasSuffix("a") { suffix = 0.25 }
        else if rawValue.hasSuffix("b") { suffix = 0.5 }
        else if rawValue.hasSuffix("c") { suffix = 0.75 }
        else if rawValue.hasSuffix("d") { suffix = 1.0 }
        else { suffix = 0 }
        return major + suffix
    }

    static func < (lhs: YDSGrade, rhs: YDSGrade) -> Bool {
        lhs.sortKey < rhs.sortKey
    }
}
