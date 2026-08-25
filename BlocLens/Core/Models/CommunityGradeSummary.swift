import Foundation

nonisolated struct CommunityGradeSummary: Codable, Equatable, Hashable, Sendable {
    let voteCount: Int
    let medianGrade: VGrade?

    init(votes: [VGrade]) {
        let validVotes = votes.filter { $0 != .unknown }.sorted()
        voteCount = validVotes.count
        medianGrade = validVotes.isEmpty ? nil : validVotes[(validVotes.count - 1) / 2]
    }

    var isDisplayEligible: Bool {
        voteCount >= 3 && medianGrade != nil
    }

    var displayGrade: VGrade? {
        isDisplayEligible ? medianGrade : nil
    }
}
