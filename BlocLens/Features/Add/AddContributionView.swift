import SwiftUI

struct AddContributionView: View {
    let action: AddAction
    let environment: AppEnvironment
    var preselectedWallZone: WallZone?

    @Environment(\.dismiss) private var dismiss
    @State private var gyms: [Gym] = []
    @State private var wallZones: [WallZone] = []
    @State private var routes: [ClimbingRoute] = []
    @State private var selectedRouteID: ClimbingRouteID?
    @State private var lockedGymName = ""
    @State private var colour = ""
    @State private var terrain: RouteTerrain = .slab
    @State private var style: RouteStyle = .staticMovement
    @State private var grade = VGrade.unknown
    @State private var publicURL = ""
    @State private var originalPostURL = ""
    @State private var author = ""
    @State private var platform = BetaPlatform.other
    @State private var selectedTags: Set<BetaTag> = []
    @State private var suspectedDuplicates: [ClimbingRoute] = []
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                if action == .addNewRoute {
                    routeFields
                } else {
                    betaFields
                }

                if let errorMessage {
                    Section {
                        Label {
                            Text(verbatim: errorMessage)
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
                            Text(verbatim: action == .addNewRoute ? "Add route" : "Share beta link")
                            Spacer()
                        }
                    }
                    .disabled(isSubmitting || !isValid)
                    .accessibilityIdentifier("add-contribution-submit")
                }
            }
            .navigationTitle(Text(verbatim: action == .addNewRoute ? "Add a new route" : "Share beta link"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text(verbatim: "Cancel") }
                }
            }
            .task { await loadOptions() }
        }
    }

    private var routeFields: some View {
        Group {
            Section {
                LabeledContent("Gym", value: lockedGymName)
                    .foregroundStyle(DesignColour.textSecondary)
            } header: {
                Text(verbatim: "Location")
            }

            Section {
                TextField("", text: $colour, prompt: Text(verbatim: "e.g. Blue"))
                    .accessibilityLabel(Text(verbatim: "Colour"))
                    .accessibilityIdentifier("add-route-colour-field")

                Picker(selection: $terrain) {
                    ForEach(RouteTerrain.allCases, id: \.self) { value in
                        Text(L10n.terrain(value)).tag(value)
                    }
                } label: {
                    helperLabel(L10n.Add.terrainField, helper: L10n.Add.terrainHelper)
                }

                Picker(selection: $style) {
                    ForEach(RouteStyle.allCases, id: \.self) { value in
                        Text(L10n.routeStyle(value)).tag(value)
                    }
                } label: {
                    helperLabel(L10n.Add.styleField, helper: L10n.Add.styleHelper)
                }

                Picker(selection: $grade) {
                    ForEach(VGrade.allCases, id: \.self) { value in
                        Text(verbatim: value.displayName).tag(value)
                    }
                } label: {
                    helperLabel(L10n.Add.gradeField, helper: L10n.Add.gradeHelper)
                }
            } header: {
                Text(verbatim: "Route details")
            } footer: {
                Text(verbatim: "Colour is required.")
            }

            if !suspectedDuplicates.isEmpty {
                Section {
                    ForEach(suspectedDuplicates) { route in
                        Text(verbatim: "\(route.colour) \(L10n.terrain(route.terrain))")
                    }
                } header: {
                    Text(verbatim: "Possible existing routes")
                } footer: {
                    Text(verbatim: "Check these routes before continuing. A possible match does not prevent publication.")
                }
            }
        }
    }

    private func helperLabel(_ title: LocalizedStringResource, helper: LocalizedStringResource) -> some View {
        HStack(spacing: DesignSpacing.xSmall) {
            Text(title)
            FieldHelperButton(helper: helper)
        }
    }

    private var betaFields: some View {
        Group {
            Section {
                Picker(selection: $selectedRouteID) {
                    ForEach(routes.filter { $0.lifecycle == .active }) { route in
                        Text(verbatim: "\(route.colour) \(L10n.terrain(route.terrain))")
                            .tag(Optional(route.id))
                    }
                } label: { Text(verbatim: "Route") }
            }

            Section {
                TextField("", text: $publicURL, prompt: Text(verbatim: "https://…"))
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .accessibilityLabel(Text(verbatim: "Public beta URL"))
                    .accessibilityIdentifier("share-beta-url-field")
                TextField("", text: $originalPostURL, prompt: Text(verbatim: "Original post URL"))
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .accessibilityLabel(Text(verbatim: "Original post URL"))
                    .accessibilityIdentifier("share-beta-original-url-field")
                TextField("", text: $author, prompt: Text(verbatim: "Original author"))
                    .accessibilityIdentifier("share-beta-author-field")
                Picker(selection: $platform) {
                    ForEach(BetaPlatform.allCases, id: \.self) { value in
                        Text(verbatim: value.rawValue.capitalized).tag(value)
                    }
                } label: { Text(verbatim: "Platform") }
            } header: {
                Text(verbatim: "External link metadata")
            } footer: {
                Text(verbatim: "BlocLens stores the public link and attribution only. No video file is transferred or stored.")
            }

            Section {
                ForEach(BetaTag.allCases, id: \.self) { tag in
                    Toggle(isOn: tagBinding(tag)) {
                        Text(verbatim: tagTitle(tag))
                    }
                }
            } header: {
                Text(verbatim: "Beta tags")
            }
        }
    }

    private var isValid: Bool {
        if action == .addNewRoute {
            return preselectedWallZone != nil
                && !colour.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return selectedRouteID != nil && URL(string: publicURL) != nil
            && URL(string: originalPostURL) != nil
            && !author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @MainActor
    private func loadOptions() async {
        do {
            async let gymRequest = environment.gymRepository.allGyms()
            async let zoneRequest = environment.gymRepository.allWallZones()
            async let routeRequest = environment.routeRepository.allRoutes()
            let values = try await (gymRequest, zoneRequest, routeRequest)
            gyms = values.0
            wallZones = values.1
            routes = values.2
            if let zone = preselectedWallZone {
                lockedGymName = gyms.first { $0.id == zone.gymID }?.name ?? ""
            }
            selectedRouteID = routes.first { $0.lifecycle == .active }?.id
        } catch {
            errorMessage = "Contribution options could not be loaded. Try again."
        }
    }

    @MainActor
    private func submit() async {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            if action == .addNewRoute {
                guard let zone = preselectedWallZone else {
                    throw RepositoryError.invalidInput
                }
                let gymID = zone.gymID
                let zoneID = zone.id
                let duplicateQuery = DuplicateRouteQuery(
                    gymID: gymID,
                    wallZoneID: zoneID,
                    colour: colour,
                    resetDate: nil
                )
                if suspectedDuplicates.isEmpty {
                    suspectedDuplicates = try await environment.routeRepository.suspectedDuplicates(for: duplicateQuery)
                    if !suspectedDuplicates.isEmpty { return }
                }
                _ = try await environment.contributionRepository.addRoute(
                    AddRouteRequest(
                        idempotencyKey: IdempotencyKey(), gymID: gymID, wallZoneID: zoneID,
                        colour: colour, terrain: terrain,
                        styles: [style],
                        subjectiveGrade: grade == .unknown ? nil : grade, setDate: nil
                    )
                )
            } else {
                guard let routeID = selectedRouteID,
                      let link = URL(string: publicURL),
                      let original = URL(string: originalPostURL) else {
                    throw RepositoryError.invalidInput
                }
                _ = try await environment.contributionRepository.shareBetaLink(
                    ShareBetaLinkRequest(
                        idempotencyKey: IdempotencyKey(), routeID: routeID, publicURL: link,
                        platform: platform, originalAuthor: author, originalPostURL: original,
                        tags: BetaTag.allCases.filter(selectedTags.contains),
                        contributorHeightCentimetres: nil, contributorArmSpanCentimetres: nil,
                        embedSupport: .sourcePlatformOnly
                    )
                )
            }
            dismiss()
        } catch let error as RepositoryError {
            errorMessage = message(for: error)
        } catch {
            errorMessage = "The contribution could not be saved. Try again."
        }
    }

    private func tagBinding(_ tag: BetaTag) -> Binding<Bool> {
        Binding(
            get: { selectedTags.contains(tag) },
            set: { selected in
                if selected { selectedTags.insert(tag) } else { selectedTags.remove(tag) }
            }
        )
    }

    private func message(for error: RepositoryError) -> String {
        switch error {
        case .invalidExternalLink: "Use a public HTTPS link and include the original attribution."
        case .conflict: "This contribution already exists."
        case .forbidden: "Your account does not have permission to make this change."
        case .offline, .network, .timeout: "This contribution needs a connection. Try again when you are online."
        default: "The contribution could not be saved. Check the details and try again."
        }
    }

    private func tagTitle(_ tag: BetaTag) -> String {
        switch tag {
        case .fullSolution: "Full solution"
        case .crux: "Crux"
        case .staticMovement: "Static"
        case .dynamicMovement: "Dynamic"
        case .shortPersonBeta: "Short climber"
        case .tallLongReachBeta: "Tall climber"
        }
    }
}

private struct FieldHelperButton: View {
    let helper: LocalizedStringResource
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Image(systemName: "info.circle")
                .foregroundStyle(DesignColour.textSecondary)
        }
        .buttonStyle(.borderless)
        .popover(isPresented: $isPresented) {
            Text(helper)
                .font(DesignTypography.supporting)
                .padding()
                .presentationCompactAdaptation(.popover)
        }
    }
}
