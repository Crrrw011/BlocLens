import SwiftUI

struct ProfileView: View {
    let environment: AppEnvironment
    @ObservedObject var session: AppSession
    @State private var editingProfile = false

    var body: some View {
        NavigationStack {
            Group {
                if let profile = session.authenticationState.profile {
                    signedInProfile(profile)
                } else {
                    signedOutProfile
                }
            }
            .navigationTitle(L10n.Profile.title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Signed Out (Flighty dense card on backgroundSecondary)

    private var signedOutProfile: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BlocSpacing.sectionGap) {
                VStack(alignment: .leading, spacing: DesignSpacing.medium) {
                    Image(systemName: "mountain.2.circle")
                        .font(.system(size: 52))
                        .foregroundStyle(BlocColor.opticBlue)
                    Text(L10n.Profile.signedOutTitle).font(.title2.bold())
                    Text(L10n.Profile.signedOutMessage)
                        .font(DesignTypography.supporting)
                        .foregroundStyle(DesignColour.textSecondary)
                    Text(L10n.Brand.tagline)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DesignColour.textTertiary)
                    Button(L10n.Authentication.signIn) {
                        _ = session.requireAuthentication(for: .account)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier("profile-sign-in-button")
                }
                .padding(DesignSpacing.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DesignColour.surfacePrimary, in: RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous).stroke(DesignColour.separator.opacity(0.5), lineWidth: 0.5) }

                publicSupportLinks
            }
            .padding(.horizontal, DesignSpacing.medium)
            .padding(.top, DesignSpacing.medium)
            .padding(.bottom, DesignSpacing.large)
        }
        .background(DesignColour.backgroundSecondary)
        .accessibilityIdentifier("profile-signed-out")
    }

    // MARK: - Signed In (Flighty: hero + compact cards, sectionGap 40, backgroundSecondary)

    private func signedInProfile(_ profile: UserProfile) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BlocSpacing.sectionGap) {
                heroCard(profile)
                climbingProfileCard(profile)
                contributorCard(profile)
                accountAccessCard
                settingsCard
                publicSupportLinks
            }
            .padding(.horizontal, DesignSpacing.medium)
            .padding(.top, DesignSpacing.small)
            .padding(.bottom, DesignSpacing.large)
        }
        .background(DesignColour.backgroundSecondary)
        .accessibilityIdentifier("profile-signed-in")
        .sheet(isPresented: $editingProfile) {
            ProfileEditView(session: session)
        }
        .sheet(isPresented: $session.shouldPresentProfileSetup) {
            ProfileEditView(session: session).interactiveDismissDisabled()
        }
    }

    private func heroCard(_ profile: UserProfile) -> some View {
        HStack(spacing: DesignSpacing.medium) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(BlocColor.opticBlue)
                .accessibilityLabel(L10n.Profile.avatarPlaceholder)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: profile.username)
                    .font(.title2.bold())
                    .foregroundStyle(DesignColour.textPrimary)
                    .lineLimit(1)
                Text(verbatim: favouriteGymName(profile.favouriteGymID))
                    .font(BlocTypography.caption)
                    .foregroundStyle(DesignColour.textSecondary)
                    .lineLimit(1)
                if profile.isTrustedContributor {
                    Label(L10n.Profile.trustedContributor, systemImage: "checkmark.seal.fill")
                        .font(BlocTypography.caption.weight(.semibold))
                        .foregroundStyle(BlocColor.opticBlue)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(DesignSpacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignColour.surfacePrimary, in: RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous).stroke(DesignColour.separator.opacity(0.5), lineWidth: 0.5) }
    }

    private func climbingProfileCard(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: DesignSpacing.small) {
            HStack(alignment: .firstTextBaseline) {
                Text(L10n.Profile.climbingProfile)
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.08)
                    .textCase(.uppercase)
                    .foregroundStyle(DesignColour.textTertiary)
                Spacer()
                Button(L10n.Profile.edit) { editingProfile = true }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(BlocColor.opticBlue)
                    .accessibilityIdentifier("profile-edit-button")
            }
            VStack(spacing: 0) {
                profileRow(L10n.Profile.height, value: measurement(profile.heightCentimetres))
                Divider().opacity(0.4).padding(.leading, DesignSpacing.medium)
                profileRow(L10n.Profile.armSpan, value: measurement(profile.armSpanCentimetres))
                Divider().opacity(0.4).padding(.leading, DesignSpacing.medium)
                profileRow(L10n.Profile.regularGrade, value: regularGradeDisplay(profile))
                Divider().opacity(0.4).padding(.leading, DesignSpacing.medium)
                profileRow(L10n.Profile.favouriteGym, value: favouriteGymName(profile.favouriteGymID))
            }
            .background(DesignColour.surfacePrimary, in: RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous).stroke(DesignColour.separator.opacity(0.5), lineWidth: 0.5) }
        }
    }

    private func contributorCard(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: DesignSpacing.small) {
            Text(L10n.Profile.contributorStatus)
                .font(.system(size: 11, weight: .bold))
                .tracking(0.08)
                .textCase(.uppercase)
                .foregroundStyle(DesignColour.textTertiary)
            VStack(alignment: .leading, spacing: DesignSpacing.small) {
                StatusChip(
                    title: session.roleContext.isTrustedContributor ? L10n.Profile.trustedContributor : L10n.Profile.contributorInProgress,
                    systemImage: "checkmark.seal",
                    colour: BlocColor.opticBlue
                )
                HStack(spacing: DesignSpacing.xSmall) {
                    Text(verbatim: "\(profile.helpfulVotes)")
                        .font(.system(size: 20, weight: .bold).monospacedDigit())
                        .foregroundStyle(DesignColour.textPrimary)
                    Text(L10n.Profile.helpfulProgressSuffix)
                        .font(BlocTypography.caption)
                        .foregroundStyle(DesignColour.textSecondary)
                }
                .accessibilityLabel("\(profile.helpfulVotes) \(String(localized: L10n.Profile.helpfulProgressSuffix))")
            }
            .padding(DesignSpacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignColour.surfacePrimary, in: RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous).stroke(DesignColour.separator.opacity(0.5), lineWidth: 0.5) }
        }
    }

    private var accountAccessCard: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.small) {
            Text(verbatim: "Account access")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.08)
                .textCase(.uppercase)
                .foregroundStyle(DesignColour.textTertiary)
            VStack(spacing: 0) {
                NavigationLink {
                    RelationshipManagementView(repository: environment.relationshipRepository)
                } label: {
                    HStack {
                        Label { Text(verbatim: "Contributors") } icon: { Image(systemName: "person.2").foregroundStyle(BlocColor.opticBlue) }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption2.weight(.semibold)).foregroundStyle(DesignColour.textTertiary)
                    }
                    .padding(.vertical, DesignSpacing.compact).padding(.horizontal, DesignSpacing.medium).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("profile-contributors-link")
                if session.isRoleContextConfirmed, !session.roleContext.managedGymIDs.isEmpty {
                    Divider().opacity(0.4).padding(.leading, DesignSpacing.medium)
                    HStack {
                        Text(verbatim: "Verified gym access").font(DesignTypography.supporting).foregroundStyle(DesignColour.textPrimary)
                        Spacer()
                        Text(verbatim: "\(session.roleContext.managedGymIDs.count)").font(BlocTypography.caption.weight(.semibold)).foregroundStyle(DesignColour.textSecondary)
                    }
                    .padding(.vertical, DesignSpacing.compact).padding(.horizontal, DesignSpacing.medium)
                    .accessibilityIdentifier("profile-verified-gym-access")
                }
                if session.isRoleContextConfirmed, session.roleContext.isModerator {
                    Divider().opacity(0.4).padding(.leading, DesignSpacing.medium)
                    HStack {
                        Label {
                            Text(verbatim: session.roleContext.isAdministrator ? "Administrator access" : "Moderator access")
                                .font(DesignTypography.supporting).foregroundStyle(DesignColour.textSecondary)
                        } icon: { Image(systemName: "checkmark.shield").foregroundStyle(BlocColor.opticBlue) }
                        Spacer()
                    }
                    .padding(.vertical, DesignSpacing.compact).padding(.horizontal, DesignSpacing.medium)
                    .accessibilityIdentifier("profile-moderation-access")
                }
            }
            .background(DesignColour.surfacePrimary, in: RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous).stroke(DesignColour.separator.opacity(0.5), lineWidth: 0.5) }
            Text(verbatim: "Role checks come from the authenticated session. Full moderation tools remain on the separate web surface.")
                .font(BlocTypography.caption)
                .foregroundStyle(DesignColour.textTertiary)
                .padding(.horizontal, DesignSpacing.xSmall)
        }
    }

    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.small) {
            Text(L10n.Settings.title)
                .font(.system(size: 11, weight: .bold))
                .tracking(0.08)
                .textCase(.uppercase)
                .foregroundStyle(DesignColour.textTertiary)
            VStack(spacing: 0) {
                NavigationLink(L10n.Settings.title) {
                    SettingsView(session: session, environment: environment)
                }
                .font(DesignTypography.supporting.weight(.medium))
                .foregroundStyle(BlocColor.opticBlue)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, DesignSpacing.compact).padding(.horizontal, DesignSpacing.medium)
                .accessibilityIdentifier("profile-settings-link")
            }
            .background(DesignColour.surfacePrimary, in: RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous).stroke(DesignColour.separator.opacity(0.5), lineWidth: 0.5) }
        }
    }

    private var publicSupportLinks: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.small) {
            Text(L10n.Profile.support)
                .font(.system(size: 11, weight: .bold))
                .tracking(0.08)
                .textCase(.uppercase)
                .foregroundStyle(DesignColour.textTertiary)
            VStack(spacing: 0) {
                supportRow(L10n.Settings.helpCentre)
                Divider().opacity(0.4).padding(.leading, DesignSpacing.medium)
                supportRow(L10n.Settings.safety)
                Divider().opacity(0.4).padding(.leading, DesignSpacing.medium)
                supportRow(L10n.Settings.privacy)
            }
            .background(DesignColour.surfacePrimary, in: RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous).stroke(DesignColour.separator.opacity(0.5), lineWidth: 0.5) }
        }
    }

    private func supportRow(_ title: LocalizedStringResource) -> some View {
        NavigationLink(title) { PlaceholderInformationView(title: title) }
            .font(DesignTypography.supporting)
            .foregroundStyle(DesignColour.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, DesignSpacing.compact).padding(.horizontal, DesignSpacing.medium)
    }

    private func profileRow(_ label: LocalizedStringResource, value: String) -> some View {
        HStack {
            Text(label).font(DesignTypography.supporting).foregroundStyle(DesignColour.textPrimary)
            Spacer(minLength: DesignSpacing.small)
            Text(verbatim: value).font(DesignTypography.supporting).foregroundStyle(DesignColour.textSecondary).lineLimit(1).minimumScaleFactor(0.85)
        }
        .padding(.vertical, DesignSpacing.compact).padding(.horizontal, DesignSpacing.medium)
    }

    private func measurement(_ value: Double?) -> String {
        guard let value else { return String(localized: L10n.Profile.notProvided) }
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .providedUnit
        formatter.numberFormatter.maximumFractionDigits = 0
        return formatter.string(from: Measurement(value: value, unit: UnitLength.centimeters))
    }

    private func regularGradeDisplay(_ profile: UserProfile) -> String {
        guard profile.gradeSystem != nil else {
            return String(localized: L10n.ProfileEdit.notSureYet)
        }
        switch profile.gradeSystem {
        case .vScale:
            return profile.regularGrade?.displayName ?? String(localized: L10n.ProfileEdit.notSureYet)
        case .yds:
            return profile.ydsGrade?.displayName ?? String(localized: L10n.ProfileEdit.notSureYet)
        case .none:
            return String(localized: L10n.ProfileEdit.notSureYet)
        }
    }

    private func favouriteGymName(_ id: GymID?) -> String {
        guard let id,
              let gym = DevelopmentFixtures.gyms.first(where: { $0.id == id }) else {
            return String(localized: L10n.Profile.notProvided)
        }
        return gym.name
    }
}

private struct SettingsView: View {
    @ObservedObject var session: AppSession
    let environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var preferences: [NotificationCategory: Bool] = [:]
    @State private var showsDeleteConfirmation = false
    @State private var isDeletingAccount = false
    @State private var showsDeleteError = false
    @State private var showsExportSheet = false
    @State private var showsPasswordSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BlocSpacing.sectionGap) {
                appearanceCard
                languageCard
                passwordCard
                notificationsCard
                supportSection
                exportCard
                accountActionsCard
                #if DEBUG
                developmentCard
                #endif
            }
            .padding(.horizontal, DesignSpacing.medium)
            .padding(.top, DesignSpacing.small)
            .padding(.bottom, DesignSpacing.large)
        }
        .background(DesignColour.backgroundSecondary)
        .navigationTitle(L10n.Settings.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadNotificationPreferences() }
        .sheet(isPresented: $showsExportSheet) { LogbookExportView(environment: environment) }
        .sheet(isPresented: $showsPasswordSheet) { ChangePasswordView(session: session) }
        .confirmationDialog(
            L10n.Settings.deleteAccountConfirmationTitle,
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.Settings.deleteAccountConfirm, role: .destructive) { Task { await deleteAccount() } }
            Button(L10n.Common.cancel, role: .cancel) {}
        } message: {
            Text(L10n.Settings.deleteAccountConfirmationMessage)
        }
        .alert(L10n.Settings.deleteAccountErrorTitle, isPresented: $showsDeleteError) {
            Button(L10n.Common.ok, role: .cancel) {}
        } message: {
            Text(L10n.Settings.deleteAccountFailedMessage)
        }
    }

    private var appearanceCard: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.small) {
            Text(L10n.Settings.appearance)
                .font(.system(size: 11, weight: .bold)).tracking(0.08).textCase(.uppercase).foregroundStyle(DesignColour.textTertiary)
            VStack(alignment: .leading, spacing: DesignSpacing.small) {
                Picker(L10n.Settings.appearance, selection: $session.appearancePreference) {
                    ForEach(AppearancePreference.allCases, id: \.self) { preference in
                        Text(L10n.appearance(preference)).tag(preference)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(DesignSpacing.medium)
            .background(DesignColour.surfacePrimary, in: RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous).stroke(DesignColour.separator.opacity(0.5), lineWidth: 0.5) }
        }
    }

    private var languageCard: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.small) {
            Text(L10n.Settings.language)
                .font(.system(size: 11, weight: .bold)).tracking(0.08).textCase(.uppercase).foregroundStyle(DesignColour.textTertiary)
            VStack(spacing: 0) {
                NavigationLink(L10n.Settings.language) {
                    List {
                        languageRow(.system, title: L10n.Settings.systemLanguage)
                        languageRow(.englishAustralian, title: L10n.Settings.englishAustralian)
                        languageRow(.korean, title: L10n.Settings.korean)
                        languageRow(.simplifiedChinese, title: L10n.Settings.simplifiedChinese)
                    }
                    .navigationTitle(L10n.Settings.language)
                }
                .font(DesignTypography.supporting)
                .foregroundStyle(DesignColour.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, DesignSpacing.compact).padding(.horizontal, DesignSpacing.medium)
                .accessibilityIdentifier("settings-language-link")
            }
            .background(DesignColour.surfacePrimary, in: RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous).stroke(DesignColour.separator.opacity(0.5), lineWidth: 0.5) }
        }
    }

    private var passwordCard: some View {
        VStack(spacing: 0) {
            Button(L10n.Settings.changePassword) { showsPasswordSheet = true }
                .font(DesignTypography.supporting.weight(.medium))
                .foregroundStyle(BlocColor.opticBlue)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, DesignSpacing.compact).padding(.horizontal, DesignSpacing.medium)
                .accessibilityIdentifier("settings-change-password")
        }
        .background(DesignColour.surfacePrimary, in: RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous).stroke(DesignColour.separator.opacity(0.5), lineWidth: 0.5) }
    }

    private var notificationsCard: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.small) {
            Text(L10n.Settings.notifications)
                .font(.system(size: 11, weight: .bold)).tracking(0.08).textCase(.uppercase).foregroundStyle(DesignColour.textTertiary)
            VStack(spacing: 0) {
                notificationRow(L10n.Settings.projectRemoval, category: .projectRemoval)
                Divider().opacity(0.4).padding(.leading, DesignSpacing.medium)
                notificationRow(L10n.Settings.gymResets, category: .gymReset)
                Divider().opacity(0.4).padding(.leading, DesignSpacing.medium)
                notificationRow(L10n.Settings.newBetaProjects, category: .newBetaForProject)
                Divider().opacity(0.4).padding(.leading, DesignSpacing.medium)
                notificationRow(L10n.Settings.followedContributors, category: .followedContributorBeta)
            }
            .background(DesignColour.surfacePrimary, in: RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous).stroke(DesignColour.separator.opacity(0.5), lineWidth: 0.5) }
        }
    }

    private func notificationRow(_ title: LocalizedStringResource, category: NotificationCategory) -> some View {
        Toggle(title, isOn: binding(category))
            .font(DesignTypography.supporting)
            .tint(BlocColor.opticBlue)
            .padding(.vertical, 6).padding(.horizontal, DesignSpacing.medium)
    }

    private var supportSection: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.small) {
            Text(verbatim: "Support")
                .font(.system(size: 11, weight: .bold)).tracking(0.08).textCase(.uppercase).foregroundStyle(DesignColour.textTertiary)
            VStack(spacing: 0) {
                NavigationLink(L10n.Settings.privacy) { PlaceholderInformationView(title: L10n.Settings.privacy) }
                    .font(DesignTypography.supporting).foregroundStyle(DesignColour.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, DesignSpacing.compact).padding(.horizontal, DesignSpacing.medium)
                Divider().opacity(0.4).padding(.leading, DesignSpacing.medium)
                NavigationLink(L10n.Settings.safety) { PlaceholderInformationView(title: L10n.Settings.safety) }
                    .font(DesignTypography.supporting).foregroundStyle(DesignColour.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, DesignSpacing.compact).padding(.horizontal, DesignSpacing.medium)
                Divider().opacity(0.4).padding(.leading, DesignSpacing.medium)
                NavigationLink(L10n.Settings.helpCentre) { PlaceholderInformationView(title: L10n.Settings.helpCentre) }
                    .font(DesignTypography.supporting).foregroundStyle(DesignColour.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, DesignSpacing.compact).padding(.horizontal, DesignSpacing.medium)
                Divider().opacity(0.4).padding(.leading, DesignSpacing.medium)
                NavigationLink(L10n.Settings.sendFeedback) { FeedbackView(environment: environment) }
                    .font(DesignTypography.supporting).foregroundStyle(DesignColour.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, DesignSpacing.compact).padding(.horizontal, DesignSpacing.medium)
            }
            .background(DesignColour.surfacePrimary, in: RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous).stroke(DesignColour.separator.opacity(0.5), lineWidth: 0.5) }
        }
    }

    private var exportCard: some View {
        VStack(spacing: 0) {
            Button(L10n.Settings.exportLogbook) { showsExportSheet = true }
                .font(DesignTypography.supporting.weight(.medium)).foregroundStyle(BlocColor.opticBlue)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, DesignSpacing.compact).padding(.horizontal, DesignSpacing.medium)
                .accessibilityIdentifier("settings-export-logbook")
        }
        .background(DesignColour.surfacePrimary, in: RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous).stroke(DesignColour.separator.opacity(0.5), lineWidth: 0.5) }
    }

    private var accountActionsCard: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.small) {
            VStack(spacing: 0) {
                Button(L10n.Settings.signOut, role: .destructive) { Task { await signOut() } }
                    .font(DesignTypography.supporting.weight(.medium))
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, DesignSpacing.compact).padding(.horizontal, DesignSpacing.medium)
                    .accessibilityIdentifier("settings-sign-out")
                Divider().opacity(0.4).padding(.leading, DesignSpacing.medium)
                Button(L10n.Settings.deleteAccount, role: .destructive) { showsDeleteConfirmation = true }
                    .font(DesignTypography.supporting.weight(.medium))
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, DesignSpacing.compact).padding(.horizontal, DesignSpacing.medium)
                    .disabled(isDeletingAccount)
                    .accessibilityIdentifier("settings-delete-account")
            }
            .background(DesignColour.surfacePrimary, in: RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous).stroke(DesignColour.separator.opacity(0.5), lineWidth: 0.5) }
        }
    }

    #if DEBUG
    private var developmentCard: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.small) {
            Text(L10n.Settings.development)
                .font(.system(size: 11, weight: .bold)).tracking(0.08).textCase(.uppercase).foregroundStyle(DesignColour.textTertiary)
            VStack(spacing: 0) {
                Button(L10n.Settings.resetOnboarding) { session.resetOnboarding() }
                    .font(DesignTypography.supporting).foregroundStyle(DesignColour.textPrimary).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, DesignSpacing.compact).padding(.horizontal, DesignSpacing.medium)
                Divider().opacity(0.4).padding(.leading, DesignSpacing.medium)
                Button(L10n.Settings.resetBetaSafety) { session.resetBetaSafetyConfirmation() }
                    .font(DesignTypography.supporting).foregroundStyle(DesignColour.textPrimary).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, DesignSpacing.compact).padding(.horizontal, DesignSpacing.medium)
                Divider().opacity(0.4).padding(.leading, DesignSpacing.medium)
                Button(L10n.Settings.mockSignOut, role: .destructive) { Task { await session.signOut() } }
                    .font(DesignTypography.supporting.weight(.medium)).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, DesignSpacing.compact).padding(.horizontal, DesignSpacing.medium)
                    .accessibilityIdentifier("settings-debug-sign-out")
            }
            .background(DesignColour.surfacePrimary, in: RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous).stroke(DesignColour.separator.opacity(0.5), lineWidth: 0.5) }
        }
    }
    #endif

    @MainActor
    private func loadNotificationPreferences() async {
        guard session.authenticationState.isSignedIn else { return }
        guard let stored = try? await environment.roleRepository.notificationPreferences() else { return }
        preferences = Dictionary(uniqueKeysWithValues: stored.map { ($0.category, $0.isEnabled) })
    }

    private func binding(_ category: NotificationCategory) -> Binding<Bool> {
        Binding(
            get: { preferences[category] ?? true },
            set: { newValue in
                preferences[category] = newValue
                guard session.authenticationState.isSignedIn else { return }
                Task { try? await environment.roleRepository.setNotificationPreference(category: category, isEnabled: newValue) }
            }
        )
    }

    private func signOut() async {
        await session.signOut()
        if session.authenticationState == .guest { dismiss() }
    }

    private func deleteAccount() async {
        isDeletingAccount = true
        showsDeleteError = false
        defer { isDeletingAccount = false }
        do {
            try await session.deleteAccount()
            dismiss()
        } catch { showsDeleteError = true }
    }

    private func languageRow(_ preference: LanguagePreference, title: LocalizedStringResource) -> some View {
        Button { session.selectLanguage(preference) } label: {
            HStack {
                Text(title).foregroundStyle(DesignColour.textPrimary)
                Spacer()
                if session.languagePreference == preference {
                    Image(systemName: "checkmark").foregroundStyle(BlocColor.opticBlue).accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .accessibilityAddTraits(session.languagePreference == preference ? .isSelected : [])
        .accessibilityIdentifier("language-option-\(preference.rawValue)")
    }
}

private struct PlaceholderInformationView: View {
    let title: LocalizedStringResource
    var body: some View {
        EmptyStateView(title: title, message: L10n.Settings.placeholderMessage, systemImage: "doc.text")
            .navigationTitle(title)
    }
}

#Preview("Profile — Logged Out") {
    let environment = AppEnvironment.development()
    ProfileView(environment: environment, session: AppSession(environment: environment))
}

#Preview("Profile — Logged In") {
    let environment = AppEnvironment.development(authenticationState: .signedIn(DevelopmentFixtures.mockProfile))
    let session = AppSession(environment: environment)
    ProfileView(environment: environment, session: session)
        .task { await session.load() }
}
