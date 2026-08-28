import SwiftUI

struct AddWallZoneView: View {
    let environment: AppEnvironment
    let session: AppSession
    let gym: Gym

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var locationDescription = ""
    @State private var wallType: WallType = .slab
    @State private var sortOrder = 0
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("", text: $name, prompt: Text(L10n.WallZone.namePrompt))
                        .accessibilityLabel(Text(L10n.WallZone.nameField))
                        .accessibilityIdentifier("add-wall-zone-name-field")
                    TextField("", text: $locationDescription, prompt: Text(L10n.WallZone.locationPrompt), axis: .vertical)
                        .lineLimit(1...3)
                        .accessibilityLabel(Text(L10n.WallZone.locationField))
                        .accessibilityIdentifier("add-wall-zone-location-field")
                    Picker(selection: $wallType) {
                        ForEach(WallType.allCases, id: \.self) { type in
                            Text(L10n.wallType(type)).tag(type)
                        }
                    } label: {
                        Text(L10n.WallZone.wallTypeField)
                    }
                } header: {
                    Text(gym.name)
                } footer: {
                    Text(L10n.WallZone.requiredFooter)
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
                            Text(L10n.WallZone.addTitle)
                            Spacer()
                        }
                    }
                    .disabled(isSubmitting || !isValid)
                    .accessibilityIdentifier("add-wall-zone-submit")
                }
            }
            .navigationTitle(L10n.WallZone.addTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.cancel) { dismiss() }
                }
            }
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @MainActor
    private func submit() async {
        if !session.requireAuthentication(for: .add(.addNewRoute)) {
            return
        }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            _ = try await environment.contributionRepository.createWallZone(
                AddWallZoneRequest(
                    idempotencyKey: IdempotencyKey(),
                    gymID: gym.id,
                    name: name,
                    locationDescription: locationDescription,
                    wallType: wallType,
                    sortOrder: sortOrder
                )
            )
            dismiss()
        } catch let error as RepositoryError {
            errorMessage = message(for: error)
        } catch {
            errorMessage = "The wall zone could not be saved. Check the details and try again."
        }
    }

    private func message(for error: RepositoryError) -> String {
        switch error {
        case .forbidden: "Your account does not have permission to make this change."
        case .conflict: "This wall zone already exists."
        case .offline, .network, .timeout: "This needs a connection. Try again when you are online."
        default: "The wall zone could not be saved. Check the details and try again."
        }
    }
}

#Preview("Add Wall Zone") {
    let environment = AppEnvironment.development(authenticationState: .signedIn(DevelopmentFixtures.mockProfile))
    AddWallZoneView(
        environment: environment,
        session: AppSession(environment: environment),
        gym: DevelopmentFixtures.gyms[0]
    )
}
