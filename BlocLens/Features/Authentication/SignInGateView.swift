import SwiftUI

struct SignInGateView: View {
    @ObservedObject var session: AppSession
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var otpCode = ""
    @State private var username = ""
    @State private var isOver16 = false
    @State private var authScreen: AuthScreen = .main
    @State private var isPasswordMode = false
    @State private var isCreateAccountFlow = false
    @State private var hasSentCode = false
    @State private var appleCoordinator = AppleSignInCoordinator()

    private enum AuthScreen {
        case main
        case emailVerify
        case emailVerifyCode
    }

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
    private static let backTitle = "Back"
    private static let otpTitle = "Enter the code"
    private static let otpBody = "We sent a code to your email."
    private static let resendCode = "Resend code"
    private static let passwordTitle = "Use password"
    private static let useEmailCode = "Use email code"
    private static let ageConfirmation = "I am 16 or older"
    private static let ageGateTitle = "You must be 16 or older to create an account"
    private static let ageGateBody = "You can continue browsing gyms and routes as a guest."
    private static let emailConfirmationTitle = "Confirm your email"
    private static let emailConfirmationBody = "We sent a confirmation link to your email. Tap it to finish creating your account, then sign in."
    private static let appleTitle = "Sign in with Apple"
    private static let googleTitle = "Sign in with Google"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSpacing.large) {
                    headerIcon
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        session.cancelSignIn()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(DesignColour.secondaryText)
                    }
                    .accessibilityLabel(L10n.Common.cancel)
                    .accessibilityIdentifier("sign-in-close-button")
                }
            }
        }
        .interactiveDismissDisabled()
        .presentationDetents([.medium, .large])
        .onChange(of: session.authenticationState) { _, newState in
            if case .error = newState {
                // A failed verify attempt may surface an error; keep the current screen.
            }
        }
    }

    private var headerIcon: some View {
        Image(systemName: "person.crop.circle.badge.checkmark")
            .font(.system(size: 54))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(DesignColour.brandPrimary)
            .frame(width: 88, height: 88)
            .background(DesignColour.brandTint, in: Circle())
    }

    @ViewBuilder
    private var content: some View {
        switch session.authenticationState {
        case .profileSetup:
            profileSetupForm
        case .ageGated:
            ageGateMessage
        case .emailConfirmationRequired:
            emailConfirmationMessage
        default:
            authContent
        }
    }

    @ViewBuilder
    private var authContent: some View {
        switch authScreen {
        case .main:
            mainAuthForm
        case .emailVerify:
            emailVerifyForm
        case .emailVerifyCode:
            emailVerifyCodeForm
        }
    }

    private var mainAuthForm: some View {
        VStack(spacing: DesignSpacing.small) {
            appleButton
            googleButton

            Button {
                hasSentCode = false
                isPasswordMode = false
                isCreateAccountFlow = true
                authScreen = .emailVerify
            } label: {
                Text(verbatim: Self.createAccountLink)
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityIdentifier("auth-create-account-link")

            Button {
                hasSentCode = false
                isPasswordMode = false
                isCreateAccountFlow = false
                authScreen = .emailVerify
            } label: {
                Text(verbatim: Self.signInInstead)
                    .font(DesignTypography.supporting)
                    .foregroundStyle(DesignColour.brandPrimary)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("auth-sign-in-instead-button")

            #if DEBUG
            Button(L10n.Authentication.mockAccount) {
                Task { await session.signInWithMockAccount() }
            }
            .buttonStyle(SecondaryButtonStyle())
            .accessibilityIdentifier("mock-sign-in-button")
            #endif
        }
    }

    private var appleButton: some View {
        Button {
            Task { await performAppleSignIn() }
        } label: {
            Label {
                Text(verbatim: Self.appleTitle)
            } icon: {
                Image(systemName: "apple.logo")
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .accessibilityIdentifier("apple-sign-in-button")
    }

    private var googleButton: some View {
        Button {
            Task { await session.signInWithGoogle() }
        } label: {
            HStack(spacing: DesignSpacing.small) {
                Image(systemName: "g.circle.fill")
                    .font(.body)
                    .foregroundStyle(.blue)
                Text(verbatim: Self.googleTitle)
            }
        }
        .buttonStyle(SecondaryButtonStyle())
        .accessibilityIdentifier("google-sign-in-button")
    }

    private var emailVerifyForm: some View {
        VStack(spacing: DesignSpacing.medium) {
            if isPasswordMode {
                TextField(Self.emailPlaceholder, text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(DesignSpacing.small)
                    .background(DesignColour.surfacePrimary, in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityIdentifier("auth-email-field")

                SecureField(Self.passwordPlaceholder, text: $password)
                    .textContentType(.password)
                    .padding(DesignSpacing.small)
                    .background(DesignColour.surfacePrimary, in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityIdentifier("auth-password-field")

                if case .error = session.authenticationState {
                    Text(verbatim: Self.signInFailed)
                        .font(.caption)
                        .foregroundStyle(DesignColour.error)
                }

                Button {
                    Task { await session.signIn(email: email, password: password) }
                } label: {
                    Text(verbatim: Self.signInTitle)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(email.isEmpty || password.isEmpty)
                .accessibilityIdentifier("auth-email-sign-in-button")

                Button {
                    isPasswordMode = false
                } label: {
                    Text(verbatim: Self.useEmailCode)
                        .font(DesignTypography.supporting)
                        .foregroundStyle(DesignColour.brandPrimary)
                }
                .buttonStyle(.plain)
            } else {
                TextField(Self.emailPlaceholder, text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(DesignSpacing.small)
                    .background(DesignColour.surfacePrimary, in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityIdentifier("auth-email-field")

                if case .error = session.authenticationState {
                    Text(verbatim: Self.signInFailed)
                        .font(.caption)
                        .foregroundStyle(DesignColour.error)
                }

                Button {
                    Task { await sendCode() }
                } label: {
                    Text(verbatim: isCreateAccountFlow ? Self.createAccountTitle : Self.signInTitle)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("auth-create-account-button")

                Button {
                    isPasswordMode = true
                } label: {
                    Text(verbatim: Self.passwordTitle)
                        .font(DesignTypography.supporting)
                        .foregroundStyle(DesignColour.secondaryText)
                }
                .buttonStyle(.plain)
            }

            Button {
                authScreen = .main
            } label: {
                Text(verbatim: Self.backTitle)
                    .font(DesignTypography.supporting)
                    .foregroundStyle(DesignColour.secondaryText)
            }
            .buttonStyle(.plain)
        }
    }

    private var emailVerifyCodeForm: some View {
        VStack(spacing: DesignSpacing.medium) {
            Text(verbatim: Self.otpTitle)
                .font(DesignTypography.cardTitle)
            Text(verbatim: Self.otpBody)
                .font(DesignTypography.body)
                .foregroundStyle(DesignColour.textSecondary)

            TextField(Self.otpTitle, text: $otpCode)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(DesignTypography.gradeEmphasis)
                .padding(DesignSpacing.small)
                .background(DesignColour.surfacePrimary, in: RoundedRectangle(cornerRadius: 10))
                .accessibilityIdentifier("auth-otp-code-field")

            if case .error = session.authenticationState {
                Text(verbatim: Self.signInFailed)
                    .font(.caption)
                    .foregroundStyle(DesignColour.error)
            }

            Button {
                Task { await verifyCode() }
            } label: {
                Text(verbatim: Self.continueTitle)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(otpCode.count < 8)
            .accessibilityIdentifier("auth-otp-verify-button")

            Button {
                Task { await sendCode() }
            } label: {
                Text(verbatim: Self.resendCode)
                    .font(DesignTypography.supporting)
                    .foregroundStyle(DesignColour.brandPrimary)
            }
            .buttonStyle(.plain)
        }
    }

    private func sendCode() async {
        hasSentCode = false
        await session.sendEmailOTP(email: email)
        if session.authenticationState.isSignedIn {
            return
        }
        // A real error surfaces as .error; here we just advance to the code screen.
        authScreen = .emailVerifyCode
    }

    private func verifyCode() async {
        await session.verifyEmailOTP(email: email, token: otpCode)
    }

    private var ageConfirmationRow: some View {
        Toggle(isOn: $isOver16) {
            Text(verbatim: Self.ageConfirmation)
                .font(DesignTypography.body)
        }
        .accessibilityIdentifier("auth-age-confirmation")
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
                .accessibilityIdentifier("auth-username-field")

            ageConfirmationRow

            if case .error = session.authenticationState {
                Text(verbatim: Self.usernameUnavailable)
                    .font(.caption)
                    .foregroundStyle(DesignColour.error)
            }

            Button {
                Task { await completeProfileSetup() }
            } label: {
                Text(verbatim: Self.continueTitle)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !isOver16)
            .accessibilityIdentifier("auth-profile-continue-button")

            Button(L10n.Common.notNow) { session.cancelSignIn() }
                .buttonStyle(CompactActionButtonStyle())
        }
    }

    private func completeProfileSetup() async {
        guard isOver16 else {
            await session.confirmAge(isOver16: false)
            return
        }
        await session.confirmAge(isOver16: true)
        await session.updateUsername(username.trimmingCharacters(in: .whitespacesAndNewlines))
        if session.authenticationState.isSignedIn {
            session.flagProfileSetupForPresentation()
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

    private var emailConfirmationMessage: some View {
        VStack(spacing: DesignSpacing.medium) {
            Image(systemName: "envelope.badge")
                .font(.system(size: 40))
                .foregroundStyle(DesignColour.brandPrimary)
            Text(verbatim: Self.emailConfirmationTitle)
                .font(DesignTypography.cardTitle)
            Text(verbatim: Self.emailConfirmationBody)
                .font(DesignTypography.body)
                .foregroundStyle(DesignColour.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                session.cancelSignIn()
            } label: {
                Text(verbatim: Self.continueAsGuestTitle)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    private func performAppleSignIn() async {
        do {
            let credential = try await appleCoordinator.credential()
            await session.signInWithApple(idToken: credential.idToken, nonce: credential.nonce)
        } catch let error as RepositoryError {
            session.failSignIn(error)
        } catch {
            session.failSignIn(.externalServiceError)
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
