import SwiftUI

struct LogbookExportView: View {
    let environment: AppEnvironment

    @Environment(\.dismiss) private var dismiss
    @State private var startDate: Date?
    @State private var endDate: Date?
    @State private var usesStartDate = false
    @State private var usesEndDate = false
    @State private var format: LogbookExportFormat = .csv
    @State private var exportState: ExportState = .idle

    private enum ExportState {
        case idle
        case loading
        case error
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(L10n.LogbookExport.format, selection: $format) {
                        ForEach(LogbookExportFormat.allCases, id: \.self) { value in
                            Text(L10n.LogbookExport.formatName(value)).tag(value)
                        }
                    }
                }

                Section(L10n.LogbookExport.dateRange) {
                    Toggle(L10n.LogbookExport.useStartDate, isOn: $usesStartDate)
                    if usesStartDate {
                        DatePicker(
                            L10n.LogbookExport.startDate,
                            selection: Binding(
                                get: { startDate ?? Date() },
                                set: { startDate = $0 }
                            ),
                            displayedComponents: .date
                        )
                    }
                    Toggle(L10n.LogbookExport.useEndDate, isOn: $usesEndDate)
                    if usesEndDate {
                        DatePicker(
                            L10n.LogbookExport.endDate,
                            selection: Binding(
                                get: { endDate ?? Date() },
                                set: { endDate = $0 }
                            ),
                            displayedComponents: .date
                        )
                    }
                }

                Section {
                    Button {
                        Task { await export() }
                    } label: {
                        if exportState == .loading {
                            ProgressView()
                        } else {
                            Text(L10n.LogbookExport.exportButton)
                        }
                    }
                    .disabled(exportState == .loading)
                    .accessibilityIdentifier("logbook-export-button")
                } footer: {
                    Text(L10n.LogbookExport.footer)
                }

                if exportState == .error {
                    Section {
                        Text(L10n.LogbookExport.errorMessage)
                            .foregroundStyle(DesignColour.error)
                    }
                }
            }
            .navigationTitle(L10n.LogbookExport.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.cancel) { dismiss() }
                }
            }
        }
    }

    private func export() async {
        exportState = .loading
        defer { exportState = .idle }
        do {
            guard let userID = environment.currentUserID() else {
                exportState = .error
                return
            }
            let entries = try await environment.logbookRepository.entries(userID: userID)
            let routes = try await environment.routeRepository.allRoutes()
            let routesByID = Dictionary(uniqueKeysWithValues: routes.map { ($0.id, $0) })
            let items = entries.compactMap { entry in
                routesByID[entry.routeID].map { LogbookRecordItem(entry: entry, route: $0) }
            }
            let filtered = LogbookExporter.filter(
                items,
                from: usesStartDate ? startDate : nil,
                to: usesEndDate ? endDate : nil
            )
            let data: Data
            let filename: String
            switch format {
            case .csv:
                data = LogbookExporter.csvData(for: filtered)
                filename = "bloclens-logbook.csv"
            case .pdf:
                data = LogbookExporter.pdfData(for: filtered)
                filename = "bloclens-logbook.pdf"
            }
            try await presentExport(data: data, filename: filename)
        } catch {
            exportState = .error
        }
    }

    @MainActor
    private func presentExport(data: Data, filename: String) async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url)
        let activity = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(activity, animated: true)
        }
    }
}
