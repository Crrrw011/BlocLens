import SwiftUI

struct FeedbackView: View {
    let environment: AppEnvironment

    @Environment(\.dismiss) private var dismiss
    @State private var category: FeedbackCategory = .issue
    @State private var message = ""
    @State private var isSubmitting = false
    @State private var showsSuccess = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                Picker(selection: $category) {
                    ForEach(FeedbackCategory.allCases, id: \.self) { value in
                        Text(L10n.feedbackCategory(value)).tag(value)
                    }
                } label: {
                    Text(L10n.Settings.feedbackCategory)
                }
            }

            Section {
                TextField(
                    "",
                    text: $message,
                    prompt: Text(L10n.Settings.feedbackMessagePrompt),
                    axis: .vertical
                )
                .lineLimit(5...12)
                .accessibilityIdentifier("feedback-message-field")
            } header: {
                Text(L10n.Settings.feedbackMessage)
            } footer: {
                Text(L10n.Settings.feedbackFooter)
            }

            if let errorMessage {
                Section {
                    Label {
                        Text(errorMessage)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle")
                    }
                    .foregroundStyle(DesignColour.destructive)
                }
            }

            Section {
                Button {
                    Task { await submit() }
                } label: {
                    HStack {
                        Spacer()
                        if isSubmitting { ProgressView() }
                        Text(L10n.Settings.feedbackSubmit)
                        Spacer()
                    }
                }
                .disabled(isSubmitting || !isValid)
                .accessibilityIdentifier("feedback-submit")
            }
        }
        .navigationTitle(L10n.Settings.sendFeedback)
        .navigationBarTitleDisplayMode(.inline)
        .alert(L10n.Settings.feedbackSuccess, isPresented: $showsSuccess) {
            Button(L10n.Common.ok, role: .cancel) { dismiss() }
        }
    }

    private var isValid: Bool {
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @MainActor
    private func submit() async {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            _ = try await environment.contributionRepository.submitFeedback(
                SubmitFeedbackRequest(
                    idempotencyKey: IdempotencyKey(),
                    category: category,
                    message: message,
                    currentPageID: nil
                )
            )
            showsSuccess = true
        } catch let error as RepositoryError {
            errorMessage = message(for: error)
        } catch {
            errorMessage = "The feedback could not be sent. Try again."
        }
    }

    private func message(for error: RepositoryError) -> String {
        switch error {
        case .offline, .network, .timeout: "This needs a connection. Try again when you are online."
        default: "The feedback could not be sent. Check the details and try again."
        }
    }
}

#Preview("Feedback") {
    NavigationStack {
        FeedbackView(environment: .development())
    }
}
