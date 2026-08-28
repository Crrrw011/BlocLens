import SwiftUI

struct AddWallZoneView: View {
    let environment: AppEnvironment
    let session: AppSession
    var gym: Gym?
    var existingZone: WallZone?

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var locationDescription = ""
    @State private var wallKind: WallKind = .regularSetWall
    @State private var surfaceMaterial: SurfaceMaterial = .plywood
    @State private var surfaceTexture: SurfaceTexture = .lightlyTextured
    @State private var hasBoltHoles = true
    @State private var sortOrder = 0
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var isEditing: Bool { existingZone != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("", text: $name, prompt: Text(L10n.WallZone.namePrompt))
                        .accessibilityLabel(Text(L10n.WallZone.nameField))
                        .accessibilityIdentifier("add-wall-zone-name-field")

                    Picker(selection: $wallKind) {
                        ForEach(WallKind.allCases, id: \.self) { kind in
                            Text(L10n.wallKind(kind)).tag(kind)
                        }
                    } label: {
                        Text(L10n.WallZone.wallKindField)
                    }

                    Picker(selection: $surfaceMaterial) {
                        ForEach(SurfaceMaterial.allCases, id: \.self) { material in
                            Text(L10n.surfaceMaterial(material)).tag(material)
                        }
                    } label: {
                        Text(L10n.WallZone.surfaceMaterialField)
                    }

                    Picker(selection: $surfaceTexture) {
                        ForEach(SurfaceTexture.allCases, id: \.self) { texture in
                            Text(L10n.surfaceTexture(texture)).tag(texture)
                        }
                    } label: {
                        Text(L10n.WallZone.surfaceTextureField)
                    }

                    Toggle(L10n.WallZone.boltHolesField, isOn: $hasBoltHoles)
                        .accessibilityIdentifier("add-wall-zone-bolt-holes")
                } header: {
                    Text(verbatim: gym?.name ?? "")
                } footer: {
                    Text(L10n.WallZone.requiredFooter)
                }

                Section(L10n.WallZone.locationField) {
                    TextField("", text: $locationDescription, prompt: Text(L10n.WallZone.locationPrompt), axis: .vertical)
                        .lineLimit(4...8)
                        .accessibilityLabel(Text(L10n.WallZone.locationField))
                        .accessibilityIdentifier("add-wall-zone-location-field")
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
                            Text(isEditing ? L10n.Common.save : L10n.WallZone.addTitle)
                            Spacer()
                        }
                    }
                    .disabled(isSubmitting || !isValid)
                    .accessibilityIdentifier("add-wall-zone-submit")
                }
            }
            .navigationTitle(isEditing ? L10n.WallZone.edit : L10n.WallZone.addTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.cancel) { dismiss() }
                }
            }
            .onAppear {
                if let existingZone {
                    name = existingZone.name
                    locationDescription = existingZone.locationDescription
                    wallKind = existingZone.wallKind
                    surfaceMaterial = existingZone.surfaceMaterial
                    surfaceTexture = existingZone.surfaceTexture
                    hasBoltHoles = existingZone.hasBoltHoles
                    sortOrder = existingZone.sortOrder
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
            if let existingZone {
                _ = try await environment.contributionRepository.updateWallZone(
                    existingZone.id,
                    request: AddWallZoneRequest(
                        idempotencyKey: IdempotencyKey(),
                        gymID: existingZone.gymID,
                        name: name,
                        locationDescription: locationDescription,
                        wallKind: wallKind,
                        surfaceMaterial: surfaceMaterial,
                        surfaceTexture: surfaceTexture,
                        hasBoltHoles: hasBoltHoles,
                        sortOrder: sortOrder
                    )
                )
            } else if let gym {
                _ = try await environment.contributionRepository.createWallZone(
                    AddWallZoneRequest(
                        idempotencyKey: IdempotencyKey(),
                        gymID: gym.id,
                        name: name,
                        locationDescription: locationDescription,
                        wallKind: wallKind,
                        surfaceMaterial: surfaceMaterial,
                        surfaceTexture: surfaceTexture,
                        hasBoltHoles: hasBoltHoles,
                        sortOrder: sortOrder
                    )
                )
            }
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
