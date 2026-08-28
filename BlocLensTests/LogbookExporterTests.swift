import Foundation
import Testing
@testable import BlocLens

struct LogbookExporterTests {
    private func makeRoute(id: String) -> ClimbingRoute {
        ClimbingRoute(
            id: ClimbingRouteID(rawValue: id),
            gymID: GymID(rawValue: "gym"),
            wallZoneID: WallZoneID(rawValue: "zone"),
            colour: "Blue",
            terrain: .slab,
            styles: [],
            subjectiveGrade: .v4,
            officialGrade: nil,
            communityGradeSummary: CommunityGradeSummary(voteCount: 0, medianGrade: nil),
            resetDate: nil,
            expectedArchiveDate: nil,
            isArchiveDateEstimated: false,
            lifecycle: .active,
            photoReference: nil,
            betaCount: 0,
            createdBy: nil
        )
    }

    private func makeEntry(routeID: String, date: Date, note: String? = nil) -> LogbookEntry {
        LogbookEntry(
            id: LogbookEntryID(rawValue: UUID().uuidString.lowercased()),
            userID: UserID(rawValue: "user"),
            routeID: ClimbingRouteID(rawValue: routeID),
            status: .sent,
            date: date,
            attemptCount: 2,
            privateNote: note,
            predictedVGrade: .v4,
            syncState: .synced,
            privacy: .privateByDefault
        )
    }

    private func makeItem(routeID: String, date: Date, note: String? = nil) -> LogbookRecordItem {
        LogbookRecordItem(entry: makeEntry(routeID: routeID, date: date, note: note), route: makeRoute(id: routeID))
    }

    @Test func filterByDateRangeIncludesOnlyMatchingDates() {
        let early = Date(timeIntervalSince1970: 1_700_000_000)
        let middle = Date(timeIntervalSince1970: 1_750_000_000)
        let late = Date(timeIntervalSince1970: 1_800_000_000)
        let items = [
            makeItem(routeID: "a", date: early),
            makeItem(routeID: "b", date: middle),
            makeItem(routeID: "c", date: late)
        ]

        let filtered = LogbookExporter.filter(
            items,
            from: Date(timeIntervalSince1970: 1_740_000_000),
            to: Date(timeIntervalSince1970: 1_760_000_000)
        )

        #expect(filtered.count == 1)
        #expect(filtered.first?.entry.routeID.rawValue == "b")
    }

    @Test func filterWithNoRangeReturnsAllItems() {
        let items = [makeItem(routeID: "a", date: Date())]
        #expect(LogbookExporter.filter(items, from: nil, to: nil).count == 1)
    }

    @Test func csvEscapesCommasQuotesAndNewlines() {
        let item = makeItem(routeID: "r", date: Date(), note: "note, with \"quotes\"\nand newline")
        let data = LogbookExporter.csvData(for: [item])
        let csv = String(data: data, encoding: .utf8) ?? ""

        // The note containing commas, quotes and a newline must be wrapped in
        // quotes with inner quotes doubled.
        #expect(csv.contains("\"note, with \"\"quotes\"\"\nand newline\""))
        #expect(csv.hasSuffix("\n"))
    }

    @Test func csvProducesHeaderRow() {
        let data = LogbookExporter.csvData(for: [])
        let csv = String(data: data, encoding: .utf8) ?? ""
        #expect(csv.hasPrefix("Date,Route,Grade,Status,Attempts,Predicted Grade,Note"))
    }

    @Test func pdfProducesNonEmptyData() {
        let items = [makeItem(routeID: "r", date: Date())]
        let data = LogbookExporter.pdfData(for: items)
        #expect(!data.isEmpty)
        #expect(data.prefix(4) == Data([0x25, 0x50, 0x44, 0x46])) // %PDF
    }
}
