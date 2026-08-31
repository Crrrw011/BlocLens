import SwiftUI

struct SignInGateView: View {
    @ObservedObject var session: AppSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
    @State private var isPasswordVisible = false
    @State private var isSigningIn = false
    @State private var showingForgotPassword = false
    @FocusState private var focusedField: Field?

    private enum Field { case email, password, otp, username }

    private var disablesPasswordAutoFill: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--disable-password-autofill")
        #else
        false
        #endif
    }

    private enum AuthScreen { case main, emailVerify, emailVerifyCode }

    private static let emailPlaceholder = "Enter your email"
    private static let passwordPlaceholder = "Enter your password"
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
    private static let appleTitle = "Continue with Apple"
    private static let googleTitle = "Continue with Google"
    private static let forgotPasswordTitle = "Forgot your password?"

    var body: some View {
        NavigationStack {
            ZStack {
                ambientBackground
                ScrollView {
                    VStack(spacing: DesignSpacing.large) {
                        header
                        glassContainer
                        if authScreen == .main {
                            footerSignUp
                        }
                    }
                    .padding(.horizontal, DesignSpacing.large)
                    .padding(.top, DesignSpacing.large)
                    .padding(.bottom, DesignSpacing.xLarge)
                }
                .scrollDismissesKeyboard(.interactively)
                .scrollIndicators(.hidden)
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button { session.cancelSignIn(); dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DesignColour.textTertiary)
                        .frame(width: 28, height: 28)
                        .background(Color.primary.opacity(0.06), in: Circle())
                }
                .accessibilityLabel(L10n.Common.close)
                .accessibilityIdentifier("sign-in-close-button")
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showingForgotPassword) {
            ForgotPasswordView(initialEmail: email)
        }
        .onChange(of: session.authenticationState) { _, newState in
            if case .error = newState { isSigningIn = false }
        }
    }

    // MARK: - Ambient Gradient (very subtle, organic, asymmetric)
    private var ambientBackground: some View {
        ZStack {
            DesignColour.backgroundPrimary
            GeometryReader { proxy in
                let w = proxy.size.width
                let h = proxy.size.height
                // Top-right soft Optic Blue
                Ellipse()
                    .fill(BlocColor.opticBlue.opacity(0.09))
                    .frame(width: w * 0.85, height: h * 0.42)
                    .blur(radius: 60)
                    .offset(x: w * 0.18, y: -h * 0.12)
                // Mid-left lavender
                Ellipse()
                    .fill(Color(red: 0.72, green: 0.68, blue: 0.98).opacity(0.07))
                    .frame(width: w * 0.78, height: h * 0.38)
                    .blur(radius: 55)
                    .offset(x: -w * 0.22, y: h * 0.18)
                // Bottom-right pink/violet extremely subtle
                Ellipse()
                    .fill(Color(red: 0.96, green: 0.62, blue: 0.82).opacity(0.05))
                    .frame(width: w * 0.7, height: h * 0.32)
                    .blur(radius: 50)
                    .offset(x: w * 0.12, y: h * 0.62)
            }
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }

    // MARK: - Header
    private var header: some View {
        VStack(spacing: DesignSpacing.small) {
            Image("BlocLensIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
                .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.primary.opacity(0.06), lineWidth: 0.5) }
            Text(isCreateAccountFlow && authScreen != .main ? "Welcome" : "Welcome Back")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(DesignColour.textPrimary)
                .tracking(-0.02 * 28)
                .animation(DesignMotion.quick, value: isCreateAccountFlow)
            Text(isCreateAccountFlow && authScreen != .main ? "Create your account to get started" : "Sign in to your account to continue")
                .font(.subheadline)
                .foregroundStyle(DesignColour.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, DesignSpacing.small)
    }

    // MARK: - Glass Container
    private var glassContainer: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.medium) {
            content
        }
        .padding(DesignSpacing.large)
        .background(glassBackground)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 32, style: .continuous).stroke(borderColor, lineWidth: 0.6) }
        .shadow(color: .black.opacity(0.06), radius: 20, y: 8)
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
    }

    private var glassBackground: some View {
        Group {
            if reduceTransparency {
                RoundedRectangle(cornerRadius: 32, style: .continuous).fill(DesignColour.surfacePrimary)
            } else if #available(iOS 26.0, *) {
                RoundedRectangle(cornerRadius: 32, style: .continuous).fill(.ultraThinMaterial)
                    .overlay { RoundedRectangle(cornerRadius: 32, style: .continuous).fill(BlocColor.opticBlueTint.opacity(0.06)) }
                    .glassEffect(.regular.tint(BlocColor.opticBlueTint.opacity(0.08)).interactive(false), in: RoundedRectangle(cornerRadius: 32, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 32, style: .continuous).fill(.ultraThinMaterial)
            }
        }
    }

    private var borderColor: Color {
        reduceTransparency ? DesignColour.separator : Color.primary.opacity(0.07)
    }

    // MARK: - Content Router
    @ViewBuilder
    private var content: some View {
        switch session.authenticationState {
        case .profileSetup: profileSetupForm
        case .ageGated: ageGateMessage
        case .emailConfirmationRequired: emailConfirmationMessage
        default: authContent
        }
    }

    @ViewBuilder
    private var authContent: some View {
        switch authScreen {
        case .main: mainAuthForm
        case .emailVerify: emailVerifyForm
        case .emailVerifyCode: emailVerifyCodeForm
        }
    }

    // MARK: - Main Auth Form — New Hierarchy
    private var mainAuthForm: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.medium) {
            // Email
            VStack(alignment: .leading, spacing: 6) {
                Text("Email Address").font(.caption.weight(.semibold)).foregroundStyle(DesignColour.textSecondary)
                HStack {
                    TextField(Self.emailPlaceholder, text: $email)
                        .focused($focusedField, equals: .email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }
                }
                .padding(.horizontal, DesignSpacing.medium)
                .frame(height: 54)
                .background(inputBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(inputBorder, lineWidth: 0.6) }
            }

            // Password
            VStack(alignment: .leading, spacing: 6) {
                Text("Password").font(.caption.weight(.semibold)).foregroundStyle(DesignColour.textSecondary)
                HStack(spacing: DesignSpacing.small) {
                    Group {
                        if isPasswordVisible {
                            TextField(Self.passwordPlaceholder, text: $password)
                                .textContentType(.password)
                        } else if disablesPasswordAutoFill {
                            TextField(Self.passwordPlaceholder, text: $password).textContentType(.oneTimeCode)
                        } else {
                            SecureField(Self.passwordPlaceholder, text: $password).textContentType(.password)
                        }
                    }
                    .focused($focusedField, equals: .password)
                    .submitLabel(.go)
                    .onSubmit { Task { await signInWithPassword() } }

                    Button { isPasswordVisible.toggle() } label: {
                        Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                            .font(.subheadline).foregroundStyle(DesignColour.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isPasswordVisible ? "Hide password" : "Show password")
                }
                .padding(.horizontal, DesignSpacing.medium)
                .frame(height: 54)
                .background(inputBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(inputBorderFocused, lineWidth: focusedField == .password ? 1 : 0.6) }

                if case .error = session.authenticationState {
                    Text(verbatim: Self.signInFailed).font(.caption).foregroundStyle(DesignColour.error)
                }
            }

            // Primary CTA
            Button { Task { await signInWithPassword() } } label: {
                ZStack {
                    if isSigningIn { ProgressView().tint(.white) } else { Text(verbatim: Self.signInTitle).font(.headline) }
                }
                .frame(maxWidth: .infinity, minHeight: 54)
                .contentShape(Capsule())
            }
            .buttonStyle(PrimaryCapsuleStyle(isLoading: isSigningIn))
            .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty || isSigningIn)
            .accessibilityIdentifier("auth-email-sign-in-button")

            // Divider OR
            HStack(spacing: DesignSpacing.small) {
                Rectangle().fill(DesignColour.separator.opacity(0.35)).frame(height: 0.5)
                Text("OR CONTINUE WITH").font(.caption2.weight(.semibold)).tracking(0.06).foregroundStyle(DesignColour.textTertiary).lineLimit(1).fixedSize(horizontal: true, vertical: false)
                Rectangle().fill(DesignColour.separator.opacity(0.35)).frame(height: 0.5)
            }
            .padding(.vertical, DesignSpacing.xSmall)

            // Social — glass quiet
            VStack(spacing: DesignSpacing.small) {
                Button { Task { await performAppleSignIn() } } label: {
                    Label { Text(verbatim: Self.appleTitle).font(.subheadline.weight(.semibold)) } icon: { Image(systemName: "apple.logo").font(.body.weight(.medium)) }
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(SocialGlassButtonStyle())
                .accessibilityIdentifier("apple-sign-in-button")

                Button { Task { await session.signInWithGoogle() } } label: {
                    Label {
                        Text(verbatim: Self.googleTitle).font(.subheadline.weight(.semibold))
                    } icon: {
                        Image(systemName: "g.circle.fill").font(.body).foregroundStyle(.blue)
                    }
                    .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(SocialGlassButtonStyle())
                .accessibilityIdentifier("google-sign-in-button")
            }

            Button("Forgot your password?") { showingForgotPassword = true }
                .font(.subheadline).foregroundStyle(DesignColour.textSecondary)
                .frame(maxWidth: .infinity).padding(.top, DesignSpacing.xSmall)
                .buttonStyle(.plain)
                .accessibilityIdentifier("forgot-password-button")

#if DEBUG
            Button(L10n.Authentication.mockAccount) { Task { await session.signInWithMockAccount() } }
                .buttonStyle(SecondaryButtonStyle()).accessibilityIdentifier("mock-sign-in-button")
#endif
        }
    }

    private var inputBackground: Color {
        reduceTransparency ? Color(uiColor: .secondarySystemBackground) : Color(uiColor: .secondarySystemBackground).opacity(0.72)
    }
    private var inputBorder: Color { DesignColour.separator.opacity(0.45) }
    private var inputBorderFocused: Color { focusedField == .password || focusedField == .email ? BlocColor.opticBlue.opacity(0.45) : inputBorder }

    // MARK: - Email Verify Forms (kept, restyled minimally to reuse glass)
    private var emailVerifyForm: some View {
        VStack(spacing: DesignSpacing.medium) {
            if isPasswordMode {
                TextField(Self.emailPlaceholder, text: $email).textContentType(.emailAddress).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(DesignSpacing.small).background(inputBackground, in: RoundedRectangle(cornerRadius: 14)).overlay { RoundedRectangle(cornerRadius: 14).stroke(inputBorder, lineWidth: 0.6) }
                    .focused($focusedField, equals: .email)
                Group {
                    if isPasswordVisible {
                        TextField(Self.passwordPlaceholder, text: $password)
                    } else if disablesPasswordAutoFill {
                        TextField(Self.passwordPlaceholder, text: $password).textContentType(.oneTimeCode)
                    } else {
                        SecureField(Self.passwordPlaceholder, text: $password).textContentType(.password)
                    }
                }
                .padding(DesignSpacing.small).background(inputBackground, in: RoundedRectangle(cornerRadius: 14)).overlay { RoundedRectangle(cornerRadius: 14).stroke(inputBorder, lineWidth: 0.6) }
                if case .error = session.authenticationState { Text(verbatim: Self.signInFailed).font(.caption).foregroundStyle(DesignColour.error) }
                Button { Task { await signInWithPassword() } } label: { Text(verbatim: Self.signInTitle) }.buttonStyle(PrimaryButtonStyle()).disabled(email.isEmpty || password.isEmpty)
                Button { isPasswordMode = false } label: { Text(verbatim: Self.useEmailCode).font(DesignTypography.supporting).foregroundStyle(DesignColour.brandPrimary) }.buttonStyle(.plain)
            } else {
                TextField(Self.emailPlaceholder, text: $email).textContentType(.emailAddress).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(DesignSpacing.small).background(inputBackground, in: RoundedRectangle(cornerRadius: 14)).overlay { RoundedRectangle(cornerRadius: 14).stroke(inputBorder, lineWidth: 0.6) }
                    .focused($focusedField, equals: .email)
                if case .error = session.authenticationState { Text(verbatim: Self.signInFailed).font(.caption).foregroundStyle(DesignColour.error) }
                Button { Task { await sendCode() } } label: { Text(verbatim: isCreateAccountFlow ? Self.createAccountTitle : Self.signInTitle) }.buttonStyle(PrimaryButtonStyle()).disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if !isCreateAccountFlow {
                    Button { isPasswordMode = true } label: { Text(verbatim: Self.passwordTitle).font(DesignTypography.supporting).foregroundStyle(DesignColour.secondaryText) }.buttonStyle(.plain)
                }
            }
            Button { authScreen = .main } label: { Text(verbatim: Self.backTitle).font(DesignTypography.supporting).foregroundStyle(DesignColour.secondaryText) }.buttonStyle(.plain)
        }
    }

    private var emailVerifyCodeForm: some View {
        VStack(spacing: DesignSpacing.medium) {
            Text(verbatim: Self.otpTitle).font(DesignTypography.cardTitle)
            Text(verbatim: Self.otpBody).font(DesignTypography.body).foregroundStyle(DesignColour.textSecondary)
            TextField(Self.otpTitle, text: $otpCode).keyboardType(.numberPad).multilineTextAlignment(.center).font(DesignTypography.gradeEmphasis)
                .padding(DesignSpacing.small).background(inputBackground, in: RoundedRectangle(cornerRadius: 14)).overlay { RoundedRectangle(cornerRadius: 14).stroke(inputBorder, lineWidth: 0.6) }
                .focused($focusedField, equals: .otp)
            if case .error = session.authenticationState { Text(verbatim: Self.signInFailed).font(.caption).foregroundStyle(DesignColour.error) }
            Button { Task { await verifyCode() } } label: { Text(verbatim: Self.continueTitle) }.buttonStyle(PrimaryButtonStyle()).disabled(otpCode.count < 8)
            Button { Task { await sendCode() } } label: { Text(verbatim: Self.resendCode).font(DesignTypography.supporting).foregroundStyle(DesignColour.brandPrimary) }.buttonStyle(.plain)
        }
    }

    private var footerSignUp: some View {
        HStack(spacing: 4) {
            Text("Don't have an account?").font(.subheadline).foregroundStyle(DesignColour.textSecondary)
            Button("Sign Up") { hasSentCode=false; isPasswordMode=false; isCreateAccountFlow=true; authScreen = .emailVerify }
                .font(.subheadline.weight(.semibold)).foregroundStyle(BlocColor.opticBlue)
        }
        .frame(maxWidth: .infinity).padding(.top, DesignSpacing.small)
    }

    private func signInWithPassword() async {
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !password.isEmpty else { return }
        isSigningIn = true
        await session.signIn(email: email, password: password)
        isSigningIn = false
    }

    // MARK: - Preserved helpers
    private var ageConfirmationRow: some View {
        Toggle(isOn: $isOver16) { Text(verbatim: Self.ageConfirmation).font(DesignTypography.body) }.accessibilityIdentifier("auth-age-confirmation")
    }
    private var profileSetupForm: some View {
        VStack(spacing: DesignSpacing.small) {
            Text(verbatim: Self.chooseUsernameTitle).font(DesignTypography.cardTitle)
            TextField(Self.usernamePlaceholder, text: $username).textInputAutocapitalization(.never).autocorrectionDisabled()
                .padding(DesignSpacing.small).background(inputBackground, in: RoundedRectangle(cornerRadius: 14)).overlay { RoundedRectangle(cornerRadius: 14).stroke(inputBorder, lineWidth: 0.6) }
                .focused($focusedField, equals: .username)
            if isCreateAccountFlow {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Set Password").font(.caption.weight(.semibold)).foregroundStyle(DesignColour.textSecondary)
                    HStack(spacing: DesignSpacing.small) {
                        Group {
                            if isPasswordVisible {
                                TextField("Create a password", text: $password).textContentType(.newPassword)
                            } else {
                                SecureField("Create a password", text: $password).textContentType(.newPassword)
                            }
                        }
                        .focused($focusedField, equals: .password)
                        Button { isPasswordVisible.toggle() } label: {
                            Image(systemName: isPasswordVisible ? "eye.slash" : "eye").font(.subheadline).foregroundStyle(DesignColour.textTertiary)
                        }.buttonStyle(.plain)
                    }
                    .padding(.horizontal, DesignSpacing.medium).frame(height: 48)
                    .background(inputBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(inputBorder, lineWidth: 0.6) }
                }
            }
            ageConfirmationRow
            if case .error = session.authenticationState { Text(verbatim: Self.usernameUnavailable).font(.caption).foregroundStyle(DesignColour.error) }
            Button { Task { await completeProfileSetup() } } label: { Text(verbatim: Self.continueTitle) }.buttonStyle(PrimaryButtonStyle()).disabled(username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !isOver16)
            Button(L10n.Common.notNow) { session.cancelSignIn() }.buttonStyle(CompactActionButtonStyle())
        }
    }
    private func completeProfileSetup() async {
        guard isOver16 else { await session.confirmAge(isOver16: false); return }
        await session.confirmAge(isOver16: true)
        await session.updateUsername(username.trimmingCharacters(in: .whitespacesAndNewlines))
        if isCreateAccountFlow && !password.isEmpty {
            try? await session.updatePassword(password)
        }
        if session.authenticationState.isSignedIn { session.flagProfileSetupForPresentation() }
    }
    private var ageGateMessage: some View {
        VStack(spacing: DesignSpacing.medium) {
            Text(verbatim: Self.ageGateTitle).font(DesignTypography.cardTitle)
            Text(verbatim: Self.ageGateBody).font(DesignTypography.body).foregroundStyle(DesignColour.textSecondary)
            Button { session.cancelSignIn() } label: { Text(verbatim: Self.continueAsGuestTitle) }.buttonStyle(PrimaryButtonStyle())
        }
    }
    private var emailConfirmationMessage: some View {
        VStack(spacing: DesignSpacing.medium) {
            Image(systemName: "envelope.badge").font(.system(size: 40)).foregroundStyle(DesignColour.brandPrimary)
            Text(verbatim: Self.emailConfirmationTitle).font(DesignTypography.cardTitle)
            Text(verbatim: Self.emailConfirmationBody).font(DesignTypography.body).foregroundStyle(DesignColour.textSecondary).multilineTextAlignment(.center)
            Button { session.cancelSignIn() } label: { Text(verbatim: Self.continueAsGuestTitle) }.buttonStyle(PrimaryButtonStyle())
        }
    }
    private func performAppleSignIn() async {
        do { let c = try await appleCoordinator.credential(); await session.signInWithApple(idToken: c.idToken, nonce: c.nonce) }
        catch let e as RepositoryError { session.failSignIn(e) } catch { session.failSignIn(.externalServiceError) }
    }
    private func sendCode() async {
        hasSentCode = false; await session.sendEmailOTP(email: email)
        if session.authenticationState.isSignedIn { return }
        authScreen = .emailVerifyCode
    }
    private func verifyCode() async { await session.verifyEmailOTP(email: email, token: otpCode) }
    private var reason: LocalizedStringResource {
        switch session.pendingIntent {
        case .revealBeta: L10n.Authentication.revealReason
        case .saveLogbook: L10n.Authentication.logbookReason
        case .add, .addRouteInZone: L10n.Authentication.contributionReason
        case .helpful: L10n.Authentication.helpfulReason
        case .account, .none: L10n.Authentication.accountReason
        }
    }
}

private struct ForgotPasswordView: View {
    var initialEmail: String
    @Environment(\.dismiss) private var dismiss
    @State private var email: String = ""
    @State private var isSent = false
    var body: some View {
        NavigationStack {
            VStack(spacing: DesignSpacing.large) {
                VStack(spacing: DesignSpacing.small) {
                    Image(systemName: "lock.rotation").font(.system(size: 48)).foregroundStyle(BlocColor.opticBlue)
                    Text("Reset Password").font(.title2.bold())
                    Text("Enter your email and we'll send you a link to reset your password.").font(.subheadline).foregroundStyle(DesignColour.textSecondary).multilineTextAlignment(.center)
                }
                .padding(.top, DesignSpacing.large)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Email Address").font(.caption.weight(.semibold)).foregroundStyle(DesignColour.textSecondary)
                    TextField("Enter your email", text: $email)
                        .textContentType(.emailAddress).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .padding(.horizontal, DesignSpacing.medium).frame(height: 54)
                        .background(Color(uiColor: .secondarySystemBackground).opacity(0.72), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(DesignColour.separator.opacity(0.45), lineWidth: 0.6) }
                }
                Button {
                    isSent = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { dismiss() }
                } label: {
                    Text(isSent ? "Link Sent ✓" : "Send Reset Link").font(.headline).frame(maxWidth: .infinity, minHeight: 54)
                }
                .buttonStyle(PrimaryCapsuleStyle(isLoading: false))
                .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSent)
                if isSent {
                    Text("Check your email for the reset link.").font(.caption).foregroundStyle(DesignColour.success).multilineTextAlignment(.center)
                }
                Spacer()
            }
            .padding(DesignSpacing.large)
            .background(DesignColour.backgroundPrimary)
            .navigationTitle("Reset Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
        .onAppear { email = initialEmail }
    }
}

private struct PrimaryCapsuleStyle: ButtonStyle {
    var isLoading = false
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 54)
            .foregroundStyle(.white)
            .background(
                (isEnabled && !isLoading ? (configuration.isPressed ? DesignColour.brandPrimaryPressed : DesignColour.brandPrimary) : DesignColour.brandPrimary.opacity(0.32)),
                in: Capsule()
            )
            .scaleEffect(configuration.isPressed && isEnabled && !isLoading ? 0.985 : 1)
            .animation(DesignMotion.quick, value: configuration.isPressed)
            .opacity(isLoading ? 0.9 : 1)
    }
}

private struct SocialGlassButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(DesignColour.textPrimary)
            .background {
                if reduceTransparency {
                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(DesignColour.surfacePrimary)
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.primary.opacity(0.06))
                        .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.primary.opacity(0.08), lineWidth: 0.5) }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(DesignMotion.quick, value: configuration.isPressed)
    }
}
