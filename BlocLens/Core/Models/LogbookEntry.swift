import Foundation

nonisolated enum LogbookStatus: String, CaseIterable, Codable, Equatable, Sendable {
    case wantToTry
    case projecting
    case sent
    case flash
}

nonisolated enum LogbookSyncState: String, Codable, Equatable, Sendable {
    case synced
    case queued
    case failed
}

nonisolated enum LogbookPrivacy: String, Codable, Equatable, Sendable {
    case privateByDefault
}

nonisolated struct LogbookEntry: Identifiable, Codable, Equatable, Hashable, Sendable {
    let id: LogbookEntryID
    let userID: UserID
    let routeID: ClimbingRouteID
    var status: LogbookStatus
    var date: Date
    var attemptCount: Int?
    var privateNote: String?
    var predictedVGrade: VGrade?
    var syncState: LogbookSyncState
    let privacy: LogbookPrivacy
}

nonisolated struct LogbookDetails: Equatable, Sendable {
    let date: Date
    let attemptCount: Int?
    let privateNote: String?
    let predictedVGrade: VGrade?
}
