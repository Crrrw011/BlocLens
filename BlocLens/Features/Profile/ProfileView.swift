import SwiftUI

struct ProfileView: View {
    let environment: AppEnvironment
    @ObservedObject var session: AppSession

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
        }
    }

    private var signedOutProfile: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: DesignSpacing.medium) {
                    Image(systemName: "mountain.2.circle")
                        .font(.system(size: 52))
                        .foregroundStyle(DesignColour.opticBlue)
                    Text(L10n.Profile.signedOutTitle).font(.title2.bold())
                    Text(L10n.Profile.signedOutMessage)
                        .foregroundStyle(DesignColour.secondaryText)
                    Text(L10n.Brand.tagline)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DesignColour.textTertiary)
                    Button(L10n.Authentication.signIn) {
                        _ = session.requireAuthentication(for: .account)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier("profile-sign-in-button")
                }
                .padding(.vertical, DesignSpacing.small)
                .cardStyle(elevated: true)
            }

            publicSupportLinks
        }
        .accessibilityIdentifier("profile-signed-out")
    }

    private func signedInProfile(_ profile: UserProfile) -> some View {
        List {
            Section {
                HStack(spacing: DesignSpacing.medium) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(DesignColour.opticBlue)
                        .accessibilityLabel(L10n.Profile.avatarPlaceholder)
                    VStack(alignment: .leading) {
                        Text(profile.username).font(.title2.bold())
                        Text(L10n.Profile.mockAccountLabel)
                            .font(.caption)
                            .foregroundStyle(DesignColour.secondaryText)
                    }
                }
            }

            Section(L10n.Profile.climbingProfile) {
                profileRow(L10n.Profile.height, value: measurement(profile.heightCentimetres))
                profileRow(L10n.Profile.armSpan, value: measurement(profile.armSpanCentimetres))
                profileRow(L10n.Profile.regularGrade, value: profile.regularGrade?.displayName ?? String(localized: L10n.Grade.unknown))
                profileRow(L10n.Profile.favouriteGym, value: favouriteGymName(profile.favouriteGymID))
            }

            Section(L10n.Profile.contributorStatus) {
                StatusChip(
                    title: session.roleContext.isTrustedContributor ? L10n.Profile.trustedContributor : L10n.Profile.contributorInProgress,
                    systemImage: "checkmark.seal",
                    colour: DesignColour.opticBlue
                )
                Text("\(profile.helpfulVotes) \(String(localized: L10n.Profile.helpfulProgressSuffix))")
                    .font(.subheadline)
                    .accessibilityLabel("\(profile.helpfulVotes) \(String(localized: L10n.Profile.helpfulProgressSuffix))")
            }

            Section {
                NavigationLink {
                    RelationshipManagementView(repository: environment.relationshipRepository)
                } label: {
                    Label {
                        Text(verbatim: "Contributors")
                    } icon: {
                        Image(systemName: "person.2")
                    }
                }
                if !session.roleContext.managedGymIDs.isEmpty {
                    LabeledContent {
                        Text(verbatim: "\(session.roleContext.managedGymIDs.count)")
                    } label: {
                        Text(verbatim: "Verified gym access")
                    }
                }
                if session.roleContext.isModerator {
                    Label {
                        Text(verbatim: session.roleContext.isAdministrator ? "Administrator access" : "Moderator access")
                    } icon: {
                        Image(systemName: "checkmark.shield")
                    }
                    .foregroundStyle(DesignColour.textSecondary)
                }
            } header: {
                Text(verbatim: "Account access")
            } footer: {
                Text(verbatim: "Role checks come from the authenticated session. Full moderation tools remain on the separate web surface.")
            }

            Section {
                NavigationLink(L10n.Settings.title) {
                    SettingsView(session: session)
                }
                .accessibilityIdentifier("profile-settings-link")
            }

            publicSupportLinks
        }
        .accessibilityIdentifier("profile-signed-in")
    }

    private var publicSupportLinks: some View {
        Section(L10n.Profile.support) {
            NavigationLink(L10n.Settings.helpCentre) { PlaceholderInformationView(title: L10n.Settings.helpCentre) }
            NavigationLink(L10n.Settings.safety) { PlaceholderInformationView(title: L10n.Settings.safety) }
            NavigationLink(L10n.Settings.privacy) { PlaceholderInformationView(title: L10n.Settings.privacy) }
        }
    }

    private func profileRow(_ label: LocalizedStringResource, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).foregroundStyle(DesignColour.secondaryText)
        }
    }

    private func measurement(_ value: Double?) -> String {
        guard let value else { return String(localized: L10n.Profile.notProvided) }
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .providedUnit
        formatter.numberFormatter.maximumFractionDigits = 0
        return formatter.string(from: Measurement(value: value, unit: UnitLength.centimeters))
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
    @State private var projectRemoval = true
    @State private var gymResets = true
    @State private var newBeta = true
    @State private var followedContributors = false

    var body: some View {
        Form {
            Section(L10n.Settings.appearance) {
                Picker(L10n.Settings.appearance, selection: $session.appearancePreference) {
                    ForEach(AppearancePreference.allCases, id: \.self) { preference in
                        Text(L10n.appearance(preference)).tag(preference)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section(L10n.Settings.language) {
                NavigationLink(L10n.Settings.language) {
                    List {
                        languageRow(.system, title: L10n.Settings.systemLanguage)
                        languageRow(.englishAustralian, title: L10n.Settings.englishAustralian)
                        languageRow(.korean, title: L10n.Settings.korean)
                        languageRow(.simplifiedChinese, title: L10n.Settings.simplifiedChinese)
                    }
                    .navigationTitle(L10n.Settings.language)
                }
                .accessibilityIdentifier("settings-language-link")
            }

            Section(L10n.Settings.notifications) {
                Toggle(L10n.Settings.projectRemoval, isOn: $projectRemoval)
                Toggle(L10n.Settings.gymResets, isOn: $gymResets)
                Toggle(L10n.Settings.newBetaProjects, isOn: $newBeta)
                Toggle(L10n.Settings.followedContributors, isOn: $followedContributors)
                Text(L10n.Settings.notificationMockNotice)
                    .font(.caption)
                    .foregroundStyle(DesignColour.secondaryText)
            }

            Section {
                NavigationLink(L10n.Settings.privacy) { PlaceholderInformationView(title: L10n.Settings.privacy) }
                NavigationLink(L10n.Settings.safety) { PlaceholderInformationView(title: L10n.Settings.safety) }
                NavigationLink(L10n.Settings.helpCentre) { PlaceholderInformationView(title: L10n.Settings.helpCentre) }
                NavigationLink(L10n.Settings.sendFeedback) { PlaceholderInformationView(title: L10n.Settings.sendFeedback) }
            }

            #if DEBUG
            Section(L10n.Settings.development) {
                Button(L10n.Settings.resetOnboarding) { session.resetOnboarding() }
                Button(L10n.Settings.resetBetaSafety) { session.resetBetaSafetyConfirmation() }
                Button(L10n.Settings.mockSignOut, role: .destructive) {
                    Task { await session.signOut() }
                }
            }
            #endif
        }
        .navigationTitle(L10n.Settings.title)
    }

    private func languageRow(_ preference: LanguagePreference, title: LocalizedStringResource) -> some View {
        Button {
            session.selectLanguage(preference)
        } label: {
            HStack {
                Text(title)
                    .foregroundStyle(DesignColour.primaryText)
                Spacer()
                if session.languagePreference == preference {
                    Image(systemName: "checkmark")
                        .foregroundStyle(DesignColour.opticBlue)
                        .accessibilityHidden(true)
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
        EmptyStateView(
            title: title,
            message: L10n.Settings.placeholderMessage,
            systemImage: "doc.text"
        )
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
