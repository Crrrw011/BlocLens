import SwiftUI

struct LogbookDetailsSheet: View {
    let entry: LogbookEntry
    let save: (LogbookDetails) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var date: Date
    @State private var attempts: Int
    @State private var privateNote: String
    @State private var predictedGrade: VGrade

    init(entry: LogbookEntry, save: @escaping (LogbookDetails) -> Void) {
        self.entry = entry
        self.save = save
        _date = State(initialValue: entry.date)
        _attempts = State(initialValue: entry.attemptCount ?? 0)
        _privateNote = State(initialValue: entry.privateNote ?? "")
        _predictedGrade = State(initialValue: entry.predictedVGrade ?? .unknown)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.Logbook.optionalDetails) {
                    DatePicker(L10n.Logbook.date, selection: $date, displayedComponents: .date)
                    Stepper(value: $attempts, in: 0 ... 99) {
                        HStack {
                            Text(L10n.Logbook.attempts)
                            Spacer()
                            Text(attempts, format: .number)
                                .foregroundStyle(DesignColour.secondaryText)
                        }
                    }
                    Picker(L10n.Logbook.predictedGrade, selection: $predictedGrade) {
                        ForEach(VGrade.allCases, id: \.self) { grade in
                            if grade == .unknown {
                                Text(L10n.Grade.unknown).tag(grade)
                            } else {
                                Text(verbatim: grade.displayName).tag(grade)
                            }
                        }
                    }
                }

                Section {
                    TextField(L10n.Logbook.privateNotePrompt, text: $privateNote, axis: .vertical)
                        .lineLimit(3 ... 6)
                } header: {
                    Label(L10n.Logbook.privateNote, systemImage: "lock.fill")
                } footer: {
                    Text(L10n.Logbook.privateByDefaultMessage)
                }
            }
            .navigationTitle(L10n.Logbook.optionalDetails)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.notNow) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Logbook.saveDetails) {
                        save(LogbookDetails(
                            date: date,
                            attemptCount: attempts == 0 ? nil : attempts,
                            privateNote: privateNote.isEmpty ? nil : privateNote,
                            predictedVGrade: predictedGrade == .unknown ? nil : predictedGrade
                        ))
                    }
                    .accessibilityIdentifier("save-logbook-details-button")
                }
            }
        }
    }
}
