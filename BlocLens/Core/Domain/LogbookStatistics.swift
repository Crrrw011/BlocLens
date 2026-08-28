import Foundation

nonisolated struct LogbookStatistics: Equatable, Sendable {
    let climbingCount: Int
    let sentCount: Int
    let flashCount: Int
    let highestGrade: VGrade?
    let gradeDistribution: [VGrade: Int]

    static let empty = LogbookStatistics(
        climbingCount: 0,
        sentCount: 0,
        flashCount: 0,
        highestGrade: nil,
        gradeDistribution: [:]
    )

    static func calculate(
        entries: [LogbookEntry],
        routesByID: [ClimbingRouteID: ClimbingRoute]
    ) -> LogbookStatistics {
        let completed = entries.filter { $0.status == .sent || $0.status == .flash }
        let completedGrades = completed.compactMap { routesByID[$0.routeID]?.displayGrade }
            .filter { $0 != .unknown }
        let distribution = completedGrades.reduce(into: [VGrade: Int]()) { result, grade in
            result[grade, default: 0] += 1
        }

        return LogbookStatistics(
            climbingCount: entries.count,
            sentCount: entries.filter { $0.status == .sent }.count,
            flashCount: entries.filter { $0.status == .flash }.count,
            highestGrade: completedGrades.max(),
            gradeDistribution: distribution
        )
    }
}
