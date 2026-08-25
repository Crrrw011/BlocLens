import SwiftUI

struct SignInGateView: View {
    @ObservedObject var session: AppSession

    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var isOver16 = false
    @State private var isCreatingAccount = false

    private static let emailPlaceholder = "Email"
    private static let passwordPlaceholder = "Password"
    private static let usernamePlaceholder = "Username"
    private static let chooseUsernameTitle = "Choose a public username"
    private static let usernameUnavailable = "That username is unavailable. Please try another."
    private static let signInFailed = "Sign in failed. Please check your details and try again."
    private static let signInTitle = "Sign In"
    private static let createAccountTitle = "Create Account"
    private static let createAccountLink = "Create an account"
    private static let signInInstead = "Sign in instead"
    private static let continueTitle = "Continue"
    private static let continueAsGuestTitle = "Continue as Guest"
    private static let ageConfirmation = "I am 16 or older"
    private static let ageGateTitle = "You must be 16 or older to create an account"
    private static let ageGateBody = "You can continue browsing gyms and routes as a guest."

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

            TextField(Self.emailPlaceholder, text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(DesignSpacing.small)
                .background(DesignColour.surfacePrimary, in: RoundedRectangle(cornerRadius: 10))

            SecureField(Self.passwordPlaceholder, text: $password)
                .textContentType(.password)
                .padding(DesignSpacing.small)
                .background(DesignColour.surfacePrimary, in: RoundedRectangle(cornerRadius: 10))

            if case .error = session.authenticationState {
                Text(verbatim: Self.signInFailed)
                    .font(.caption)
                    .foregroundStyle(DesignColour.error)
            }

            if isCreatingAccount {
                Button {
                    Task { await createAccount() }
                } label: {
                    Text(verbatim: Self.createAccountTitle)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(email.isEmpty || password.isEmpty || !isOver16)

                Button {
                    isCreatingAccount = false
                } label: {
                    Text(verbatim: Self.signInInstead)
                }
                .buttonStyle(CompactActionButtonStyle())
            } else {
                Button {
                    Task { await session.signIn(email: email, password: password) }
                } label: {
                    Text(verbatim: Self.signInTitle)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(email.isEmpty || password.isEmpty)

                Button {
                    isCreatingAccount = true
                } label: {
                    Text(verbatim: Self.createAccountLink)
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
        Toggle(isOn: $isOver16) {
            Text(verbatim: Self.ageConfirmation)
                .font(DesignTypography.body)
        }
    }

    private var profileSetupForm: some View {
        VStack(spacing: DesignSpacing.small) {
            Text(verbatim: Self.chooseUsernameTitle)
                .font(DesignTypography.cardTitle)

            TextField(Self.usernamePlaceholder, text: $username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(DesignSpacing.small)
                .background(DesignColour.surfacePrimary, in: RoundedRectangle(cornerRadius: 10))

            if case .error = session.authenticationState {
                Text(verbatim: Self.usernameUnavailable)
                    .font(.caption)
                    .foregroundStyle(DesignColour.error)
            }

            Button {
                Task { await session.updateUsername(username.trimmingCharacters(in: .whitespacesAndNewlines)) }
            } label: {
                Text(verbatim: Self.continueTitle)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Button(L10n.Common.notNow) { session.cancelSignIn() }
                .buttonStyle(CompactActionButtonStyle())
        }
    }

    private var ageGateMessage: some View {
        VStack(spacing: DesignSpacing.medium) {
            Text(verbatim: Self.ageGateTitle)
                .font(DesignTypography.cardTitle)
            Text(verbatim: Self.ageGateBody)
                .font(DesignTypography.body)
                .foregroundStyle(DesignColour.textSecondary)

            Button {
                session.cancelSignIn()
            } label: {
                Text(verbatim: Self.continueAsGuestTitle)
            }
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
