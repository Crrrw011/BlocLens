import SwiftUI

struct RelationshipManagementView: View {
    let repository: any RelationshipRepository
    @State private var profiles: [PublicUserProfile] = []
    @State private var states: [UserID: UserRelationshipState] = [:]
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                LoadingStateView()
            } else if let errorMessage {
                ContentUnavailableView {
                    Label {
                        Text(verbatim: "Contributors unavailable")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle")
                    }
                } description: {
                    Text(verbatim: errorMessage)
                } actions: {
                    Button { Task { await load() } } label: { Text(verbatim: "Try again") }
                }
            } else if profiles.isEmpty {
                ContentUnavailableView {
                    Label {
                        Text(verbatim: "No contributors to show")
                    } icon: {
                        Image(systemName: "person.2")
                    }
                } description: {
                    Text(verbatim: "Accounts you block are removed from this list.")
                }
            } else {
                List(profiles, id: \.userID) { profile in
                    contributorRow(profile)
                }
            }
        }
        .navigationTitle(Text(verbatim: "Contributors"))
        .task { await load() }
    }

    private func contributorRow(_ profile: PublicUserProfile) -> some View {
        let state = states[profile.userID] ?? UserRelationshipState(isFollowing: false, isBlocked: false)
        return VStack(alignment: .leading, spacing: DesignSpacing.small) {
            HStack {
                Image(systemName: "person.crop.circle")
                    .font(.title2)
                    .foregroundStyle(DesignColour.opticBlue)
                VStack(alignment: .leading) {
                    Text(verbatim: profile.username).font(.headline)
                    if profile.isTrustedContributor {
                        Label {
                            Text(verbatim: "Trusted contributor")
                        } icon: {
                            Image(systemName: "checkmark.seal")
                        }
                        .font(.caption)
                        .foregroundStyle(DesignColour.textSecondary)
                    }
                }
                Spacer()
            }
            HStack {
                Button {
                    Task { await toggleFollow(profile.userID, state: state) }
                } label: {
                    Text(verbatim: state.isFollowing ? "Unfollow" : "Follow")
                }
                .buttonStyle(CompactActionButtonStyle())
                .disabled(state.isBlocked)
                .accessibilityIdentifier("relationship-follow-\(profile.userID.rawValue)")

                Button(role: state.isBlocked ? nil : .destructive) {
                    Task { await toggleBlock(profile.userID, state: state) }
                } label: {
                    Text(verbatim: state.isBlocked ? "Unblock" : "Block")
                }
                .buttonStyle(CompactActionButtonStyle())
                .accessibilityIdentifier("relationship-block-\(profile.userID.rawValue)")
            }
        }
        .padding(.vertical, DesignSpacing.xSmall)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("relationship-profile-\(profile.userID.rawValue)")
    }

    @MainActor
    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            async let visibleRequest = repository.publicProfiles()
            async let blockedRequest = repository.blockedProfiles()
            let loaded = try await (visibleRequest, blockedRequest)
            let loadedProfiles = loaded.0 + loaded.1
            var loadedStates: [UserID: UserRelationshipState] = [:]
            for profile in loadedProfiles {
                loadedStates[profile.userID] = try await repository.state(with: profile.userID)
            }
            profiles = loadedProfiles
            states = loadedStates
        } catch {
            errorMessage = "Relationship settings could not be loaded."
        }
        isLoading = false
    }

    @MainActor
    private func toggleFollow(_ userID: UserID, state: UserRelationshipState) async {
        do {
            if state.isFollowing {
                try await repository.unfollow(userID: userID, idempotencyKey: IdempotencyKey())
            } else {
                try await repository.follow(userID: userID, idempotencyKey: IdempotencyKey())
            }
            states[userID] = try await repository.state(with: userID)
        } catch {
            errorMessage = "The follow setting could not be changed."
        }
    }

    @MainActor
    private func toggleBlock(_ userID: UserID, state: UserRelationshipState) async {
        do {
            if state.isBlocked {
                try await repository.unblock(userID: userID, idempotencyKey: IdempotencyKey())
            } else {
                try await repository.block(userID: userID, idempotencyKey: IdempotencyKey())
            }
            states[userID] = try await repository.state(with: userID)
            async let visibleRequest = repository.publicProfiles()
            async let blockedRequest = repository.blockedProfiles()
            let loaded = try await (visibleRequest, blockedRequest)
            profiles = loaded.0 + loaded.1
        } catch {
            errorMessage = "The block setting could not be changed."
        }
    }
}
