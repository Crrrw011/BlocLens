import SwiftUI

struct SignInGateView: View {
    @ObservedObject var session: AppSession

    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var isOver16 = false
    @State private var isCreatingAccount = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSpacing.large) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 54))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(DesignColour.brandPrimary)
                        .frame(width: 88, height: 88)
                        .background(DesignColour.brandTint, in: Circle())

                    Text(L10n.Authentication.gateTitle)
                        .font(DesignTypography.largeScreenTitle)
                    Text(reason)
                        .font(DesignTypography.body)
                        .foregroundStyle(DesignColour.textSecondary)
                        .lineSpacing(3)

                    content
                }
                .padding(DesignSpacing.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .background(DesignColour.backgroundPrimary)
            .navigationTitle(L10n.Authentication.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled()
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private var content: some View {
        switch session.authenticationState {
        case .profileSetup:
            profileSetupForm
        case .ageGated:
            ageGateMessage
        default:
            signInForm
        }
    }

    private var signInForm: some View {
        VStack(spacing: DesignSpacing.small) {
            if isCreatingAccount {
                ageConfirmationRow
            }

            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(DesignSpacing.small)
                .background(DesignColour.surfacePrimary, in: RoundedRectangle(cornerRadius: 10))

            SecureField("Password", text: $password)
                .textContentType(.password)
                .padding(DesignSpacing.small)
                .background(DesignColour.surfacePrimary, in: RoundedRectangle(cornerRadius: 10))

            if case .error = session.authenticationState {
                Text("Sign in failed. Please check your details and try again.")
                    .font(.caption)
                    .foregroundStyle(DesignColour.error)
            }

            if isCreatingAccount {
                Button("Create Account") {
                    Task { await createAccount() }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(email.isEmpty || password.isEmpty || !isOver16)

                Button("Sign in instead") {
                    isCreatingAccount = false
                }
                .buttonStyle(CompactActionButtonStyle())
            } else {
                Button("Sign In") {
                    Task { await session.signIn(email: email, password: password) }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(email.isEmpty || password.isEmpty)

                Button("Create an account") {
                    isCreatingAccount = true
                }
                .buttonStyle(CompactActionButtonStyle())
            }

            #if DEBUG
            Button(L10n.Authentication.mockAccount) {
                Task { await session.signInWithMockAccount() }
            }
            .buttonStyle(SecondaryButtonStyle())
            .accessibilityIdentifier("mock-sign-in-button")
            #endif
        }
    }

    private var ageConfirmationRow: some View {
        Toggle("I am 16 or older", isOn: $isOver16)
            .font(DesignTypography.body)
    }

    private var profileSetupForm: some View {
        VStack(spacing: DesignSpacing.small) {
            Text("Choose a public username")
                .font(DesignTypography.cardTitle)

            TextField("Username", text: $username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(DesignSpacing.small)
                .background(DesignColour.surfacePrimary, in: RoundedRectangle(cornerRadius: 10))

            if case .error = session.authenticationState {
                Text("That username is unavailable. Please try another.")
                    .font(.caption)
                    .foregroundStyle(DesignColour.error)
            }

            Button("Continue") {
                Task { await session.updateUsername(username.trimmingCharacters(in: .whitespacesAndNewlines)) }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Button(L10n.Common.notNow) { session.cancelSignIn() }
                .buttonStyle(CompactActionButtonStyle())
        }
    }

    private var ageGateMessage: some View {
        VStack(spacing: DesignSpacing.medium) {
            Text("You must be 16 or older to create an account")
                .font(DesignTypography.cardTitle)
            Text("You can continue browsing gyms and routes as a guest.")
                .font(DesignTypography.body)
                .foregroundStyle(DesignColour.textSecondary)

            Button("Continue as Guest") { session.cancelSignIn() }
                .buttonStyle(PrimaryButtonStyle())
        }
    }

    private func createAccount() async {
        guard isOver16 else {
            await session.confirmAge(isOver16: false)
            return
        }
        await session.signUp(email: email, password: password)
        if session.authenticationState.isProfileSetup {
            await session.confirmAge(isOver16: true)
        }
    }

    private var reason: LocalizedStringResource {
        switch session.pendingIntent {
        case .revealBeta: L10n.Authentication.revealReason
        case .saveLogbook: L10n.Authentication.logbookReason
        case .add: L10n.Authentication.contributionReason
        case .helpful: L10n.Authentication.helpfulReason
        case .account, .none: L10n.Authentication.accountReason
        }
    }
}
