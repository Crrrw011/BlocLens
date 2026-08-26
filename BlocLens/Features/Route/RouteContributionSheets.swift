import SwiftUI

enum RouteContributionSheet: String, Identifiable {
    case photo
    case correction
    case comment
    case reportRoute
    case reportBeta
    case reset

    var id: String { rawValue }
}

struct ResetConfirmationSheet: View {
    let submit: () async -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: DesignSpacing.large) {
                Image(systemName: "arrow.clockwise.circle")
                    .font(.system(size: 48))
                    .foregroundStyle(DesignColour.opticBlue)
                Text(verbatim: "Confirm this wall was reset today")
                    .font(.title2.bold())
                Text(verbatim: "A verified gym confirmation takes effect immediately. Otherwise, confirmations from three different climbers are required.")
                    .foregroundStyle(DesignColour.textSecondary)
                Spacer()
                Button {
                    isSubmitting = true
                    Task {
                        if await submit() { dismiss() }
                        isSubmitting = false
                    }
                } label: {
                    Text(verbatim: "Confirm reset")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isSubmitting)
            }
            .padding()
            .navigationTitle(Text(verbatim: "Wall reset"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text(verbatim: "Cancel") }
                }
            }
        }
    }
}

struct RoutePhotoMetadataSheet: View {
    let username: String
    let submit: (URL) async -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var urlText = ""
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("", text: $urlText, prompt: Text(verbatim: "Public HTTPS image URL"))
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .accessibilityLabel(Text(verbatim: "Public image URL"))
                    LabeledContent {
                        Text(verbatim: username)
                    } label: {
                        Text(verbatim: "Credit")
                    }
                } footer: {
                    Text(verbatim: "Only the public URL and account credit are saved. BlocLens does not upload or store the image file in this stage.")
                }
            }
            .navigationTitle(Text(verbatim: "Add route photo metadata"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text(verbatim: "Cancel") }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        guard let url = URL(string: urlText) else { return }
                        isSubmitting = true
                        Task {
                            if await submit(url) { dismiss() }
                            isSubmitting = false
                        }
                    } label: { Text(verbatim: "Save") }
                    .disabled(isSubmitting || URL(string: urlText)?.scheme?.lowercased() != "https")
                }
            }
        }
    }
}

struct RouteCorrectionSheet: View {
    let submit: (RouteCorrectionIssue, String, String) async -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var issue = RouteCorrectionIssue.other
    @State private var proposedValue = ""
    @State private var explanation = ""
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            Form {
                Picker(selection: $issue) {
                    ForEach(RouteCorrectionIssue.allCases, id: \.self) { value in
                        Text(verbatim: issueTitle(value)).tag(value)
                    }
                } label: { Text(verbatim: "Issue") }
                TextField("", text: $proposedValue, prompt: Text(verbatim: "Correct value (optional)"))
                Section {
                    TextEditor(text: $explanation)
                        .frame(minHeight: 120)
                        .accessibilityLabel(Text(verbatim: "Explanation"))
                } footer: {
                    Text(verbatim: "Three corrections from different climbers temporarily hide a route for review. Repeating the same report does not increase the count.")
                }
            }
            .navigationTitle(Text(verbatim: "Suggest a correction"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text(verbatim: "Cancel") }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        isSubmitting = true
                        Task {
                            if await submit(issue, proposedValue, explanation) { dismiss() }
                            isSubmitting = false
                        }
                    } label: { Text(verbatim: "Submit") }
                    .disabled(isSubmitting || (proposedValue.isEmpty && explanation.isEmpty))
                }
            }
        }
    }

    private func issueTitle(_ issue: RouteCorrectionIssue) -> String {
        switch issue {
        case .colour: "Colour"
        case .label: "Label"
        case .grade: "Gym grade"
        case .resetDate: "Reset date"
        case .routeStatus: "Route status"
        case .photo: "Photo"
        case .other: "Other"
        }
    }
}

struct BetaCommentSheet: View {
    let submit: (String) async -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var bodyText = ""
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $bodyText)
                        .frame(minHeight: 120)
                        .accessibilityLabel(Text(verbatim: "Comment"))
                    HStack {
                        Spacer()
                        Text(verbatim: "\(bodyText.count) of 200")
                            .font(.caption)
                            .foregroundStyle(bodyText.count > 200 ? DesignColour.destructive : DesignColour.textSecondary)
                    }
                } footer: {
                    Text(verbatim: "Comments are public and belong to this beta link. Replies are not supported.")
                }
            }
            .navigationTitle(Text(verbatim: "Add comment"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text(verbatim: "Cancel") }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        isSubmitting = true
                        Task {
                            if await submit(bodyText) { dismiss() }
                            isSubmitting = false
                        }
                    } label: { Text(verbatim: "Publish") }
                    .disabled(isSubmitting || bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || bodyText.count > 200)
                }
            }
        }
    }
}

struct ContentReportSheet: View {
    let submit: (ContentReportCategory, String) async -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var category = ContentReportCategory.other
    @State private var details = ""
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            Form {
                Picker(selection: $category) {
                    ForEach(ContentReportCategory.allCases, id: \.self) { value in
                        Text(verbatim: categoryTitle(value)).tag(value)
                    }
                } label: { Text(verbatim: "Reason") }
                TextField("", text: $details, prompt: Text(verbatim: "Additional details (optional)"), axis: .vertical)
                    .lineLimit(3...8)
                Text(verbatim: category.isSevere
                    ? "Severe safety reports are temporarily hidden after one valid report and prioritised for review."
                    : "Ordinary content is temporarily hidden after reports from three different accounts.")
                    .font(.caption)
                    .foregroundStyle(DesignColour.textSecondary)
            }
            .navigationTitle(Text(verbatim: "Report content"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text(verbatim: "Cancel") }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        isSubmitting = true
                        Task {
                            if await submit(category, details) { dismiss() }
                            isSubmitting = false
                        }
                    } label: { Text(verbatim: "Submit report") }
                    .disabled(isSubmitting)
                }
            }
        }
    }

    private func categoryTitle(_ value: ContentReportCategory) -> String {
        switch value {
        case .wrongRoute: "Wrong route"
        case .brokenLink: "Broken link"
        case .unsafeContent: "Unsafe content"
        case .nudity: "Nudity"
        case .harassment: "Harassment"
        case .violence: "Violence"
        case .minorPrivacy: "Minor privacy"
        case .spam: "Spam"
        case .other: "Other"
        }
    }
}
