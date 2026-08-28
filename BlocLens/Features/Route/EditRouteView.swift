import SwiftUI

struct EditRouteView: View {
    let environment: AppEnvironment
    let session: AppSession
    let route: ClimbingRoute

    @Environment(\.dismiss) private var dismiss
    @State private var colour = ""
    @State private var terrain: RouteTerrain = .slab
    @State private var style: RouteStyle = .staticMovement
    @State private var grade = VGrade.unknown
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("", text: $colour, prompt: Text(verbatim: "e.g. Blue"))
                        .accessibilityIdentifier("edit-route-colour-field")

                    Picker(selection: $terrain) {
                        ForEach(RouteTerrain.allCases, id: \.self) { value in
                            Text(L10n.terrain(value)).tag(value)
                        }
                    } label: {
                        Text(L10n.Add.terrainField)
                    }

                    Picker(selection: $style) {
                        ForEach(RouteStyle.allCases, id: \.self) { value in
                            Text(L10n.routeStyle(value)).tag(value)
                        }
                    } label: {
                        Text(L10n.Add.styleField)
                    }

                    Picker(selection: $grade) {
                        ForEach(VGrade.allCases, id: \.self) { value in
                            Text(verbatim: value.displayName).tag(value)
                        }
                    } label: {
                        Text(L10n.Add.gradeField)
                    }
                } header: {
                    Text(verbatim: "Route details")
                } footer: {
                    Text(verbatim: "Colour is required.")
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
                            Text(L10n.Common.save)
                            Spacer()
                        }
                    }
                    .disabled(isSubmitting || !isValid)
                    .accessibilityIdentifier("edit-route-submit")
                }
            }
            .navigationTitle(L10n.Route.edit)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.cancel) { dismiss() }
                }
            }
            .onAppear {
                colour = route.colour
                terrain = route.terrain
                style = route.styles.first ?? .staticMovement
                grade = route.subjectiveGrade ?? .unknown
            }
        }
    }

    private var isValid: Bool {
        !colour.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @MainActor
    private func submit() async {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            _ = try await environment.contributionRepository.updateRoute(
                route.id,
                request: AddRouteRequest(
                    idempotencyKey: IdempotencyKey(),
                    gymID: route.gymID,
                    wallZoneID: route.wallZoneID,
                    colour: colour,
                    terrain: terrain,
                    styles: [style],
                    subjectiveGrade: grade == .unknown ? nil : grade,
                    setDate: nil
                )
            )
            dismiss()
        } catch let error as RepositoryError {
            errorMessage = message(for: error)
        } catch {
            errorMessage = "The route could not be saved. Check the details and try again."
        }
    }

    private func message(for error: RepositoryError) -> String {
        switch error {
        case .forbidden: "Your account does not have permission to make this change."
        case .conflict: "This route already exists."
        case .offline, .network, .timeout: "This needs a connection. Try again when you are online."
        default: "The route could not be saved. Check the details and try again."
        }
    }
}

#Preview("Edit Route") {
    let environment = AppEnvironment.development(authenticationState: .signedIn(DevelopmentFixtures.mockProfile))
    EditRouteView(
        environment: environment,
        session: AppSession(environment: environment),
        route: DevelopmentFixtures.routes[0]
    )
}
