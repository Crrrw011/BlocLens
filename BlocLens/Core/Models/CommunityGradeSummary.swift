import Foundation

nonisolated struct CommunityGradeSummary: Codable, Equatable, Hashable, Sendable {
    let voteCount: Int
    let medianGrade: VGrade?

    init(votes: [VGrade]) {
        let validVotes = votes.filter { $0 != .unknown }.sorted()
        voteCount = validVotes.count
        medianGrade = validVotes.isEmpty ? nil : validVotes[(validVotes.count - 1) / 2]
    }

    init(voteCount: Int, medianGrade: VGrade?) {
        self.voteCount = max(0, voteCount)
        self.medianGrade = voteCount >= 3 ? medianGrade : nil
    }

    var isDisplayEligible: Bool {
        voteCount >= 3 && medianGrade != nil
    }

    var displayGrade: VGrade? {
        isDisplayEligible ? medianGrade : nil
    }
}
