import SwiftUI

struct ReportWallZoneView: View {
    let environment: AppEnvironment
    let wallZone: WallZone

    var body: some View {
        ContentReportSheet { category, details in
            do {
                _ = try await environment.contributionRepository.reportContent(
                    SubmitContentReportRequest(
                        idempotencyKey: IdempotencyKey(),
                        targetType: .wallZone,
                        targetID: wallZone.id.rawValue,
                        category: category,
                        details: details
                    )
                )
                return true
            } catch {
                return false
            }
        }
    }
}
