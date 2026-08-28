import Foundation
import UIKit

nonisolated enum LogbookExportFormat: String, CaseIterable, Sendable {
    case csv
    case pdf
}

nonisolated struct LogbookExportRequest: Equatable, Sendable {
    let startDate: Date?
    let endDate: Date?
    let format: LogbookExportFormat
}

nonisolated enum LogbookExporter {
    static func filter(
        _ items: [LogbookRecordItem],
        from startDate: Date?,
        to endDate: Date?
    ) -> [LogbookRecordItem] {
        items.filter { item in
            let date = item.entry.date
            if let startDate, date < startDate { return false }
            if let endDate, date > endDate { return false }
            return true
        }
    }

    static func csvData(for items: [LogbookRecordItem]) -> Data {
        var rows = ["Date,Route,Grade,Status,Attempts,Predicted Grade,Note"]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for item in items {
            let entry = item.entry
            let route = item.route
            let fields = [
                formatter.string(from: entry.date),
                route.colour,
                route.displayGrade?.displayName ?? "",
                entry.status.rawValue,
                entry.attemptCount.map(String.init) ?? "",
                entry.predictedVGrade?.displayName ?? "",
                escapeCSV(entry.privateNote ?? "")
            ]
            rows.append(fields.joined(separator: ","))
        }
        return (rows.joined(separator: "\n") + "\n").data(using: .utf8) ?? Data()
    }

    static func pdfData(for items: [LogbookRecordItem]) -> Data {
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextCreator as String: "BlocLens",
            kCGPDFContextTitle as String: "Logbook export"
        ]
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        return renderer.pdfData { context in
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")

            var y = 72.0
            func draw(_ text: String, font: UIFont) {
                let attributes: [NSAttributedString.Key: Any] = [.font: font]
                text.draw(at: CGPoint(x: 72, y: y), withAttributes: attributes)
                y += font.lineHeight + 4
            }
            func newPageIfNeeded() {
                if y > pageRect.height - 72 {
                    context.beginPage()
                    y = 72
                }
            }

            draw("BlocLens Logbook", font: .boldSystemFont(ofSize: 20))
            y += 8

            for item in items {
                newPageIfNeeded()
                let entry = item.entry
                let route = item.route
                let grade = entry.predictedVGrade?.displayName
                    ?? route.displayGrade?.displayName
                    ?? "Unknown"
                draw("\(dateFormatter.string(from: entry.date))  ·  \(route.colour)  ·  \(grade)", font: .boldSystemFont(ofSize: 13))
                var detail = "Status: \(entry.status.rawValue)"
                if let attempts = entry.attemptCount { detail += "  ·  Attempts: \(attempts)" }
                if let note = entry.privateNote { detail += "\n\(note)" }
                draw(detail, font: .systemFont(ofSize: 11))
                y += 6
            }
        }
    }

    private static func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}
