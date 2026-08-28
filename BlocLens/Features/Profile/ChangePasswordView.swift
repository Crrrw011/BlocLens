import SwiftUI

struct ChangePasswordView: View {
    @ObservedObject var session: AppSession
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var confirmation = ""
    @State private var isSaving = false
    @State private var showsError = false

    private let minimumLength = 8

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.Password.newTitle) {
                    SecureField(L10n.Password.newPlaceholder, text: $password)
                        .textContentType(.newPassword)
                        .accessibilityIdentifier("password-new-field")

                    SecureField(L10n.Password.confirmPlaceholder, text: $confirmation)
                        .textContentType(.newPassword)
                        .accessibilityIdentifier("password-confirm-field")

                    Text(L10n.Password.requirement)
                        .font(DesignTypography.caption)
                        .foregroundStyle(DesignColour.secondaryText)
                }

                if showsError {
                    Section {
                        Label {
                            Text(L10n.Password.mismatchError)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle")
                        }
                        .foregroundStyle(DesignColour.error)
                    }
                }
            }
            .navigationTitle(L10n.Password.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text(L10n.Common.save)
                        }
                    }
                    .disabled(isSaving || !isValid)
                }
            }
        }
    }

    private var isValid: Bool {
        password.count >= minimumLength && password == confirmation
    }

    private func save() async {
        guard isValid else {
            showsError = true
            return
        }
        isSaving = true
        showsError = false
        defer { isSaving = false }
        do {
            try await session.updatePassword(password)
            dismiss()
        } catch {
            showsError = true
        }
    }
}
