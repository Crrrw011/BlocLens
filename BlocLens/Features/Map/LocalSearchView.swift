import SwiftUI

struct LocalSearchView: View {
    let environment: AppEnvironment
    @ObservedObject var session: AppSession
    let selectResult: (LocalSearchResult) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: LocalSearchViewModel

    init(environment: AppEnvironment, session: AppSession, selectResult: @escaping (LocalSearchResult) -> Void) {
        self.environment = environment
        self.session = session
        self.selectResult = selectResult
        _viewModel = StateObject(
            wrappedValue: LocalSearchViewModel(
                gymRepository: environment.gymRepository,
                routeRepository: environment.routeRepository,
                googlePlacesClient: environment.googlePlacesClient
            )
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterBar
                results
            }
            .navigationTitle(L10n.Search.title)
            .searchable(text: $viewModel.query, prompt: Text(L10n.Search.prompt))
            .onSubmit(of: .search) { Task { await viewModel.search() } }
            .onChange(of: viewModel.gradeBand) { _, _ in Task { await viewModel.search() } }
            .onChange(of: viewModel.includesArchived) { _, _ in Task { await viewModel.search() } }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.close) { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(L10n.Search.clear) { viewModel.clear() }
                        .disabled(viewModel.query.isEmpty && viewModel.gradeBand == .all)
                }
            }
        }
    }

    private var filterBar: some View {
        HStack {
            Picker(L10n.Filter.grade, selection: $viewModel.gradeBand) {
                ForEach(GradeBand.allCases, id: \.self) { band in
                    Text(L10n.gradeBand(band)).tag(band)
                }
            }
            .pickerStyle(.menu)

            Toggle(L10n.Filter.showHistory, isOn: $viewModel.includesArchived)
                .toggleStyle(.switch)
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var results: some View {
        if viewModel.isLoading {
            LoadingStateView().frame(maxHeight: .infinity)
        } else if viewModel.error != nil {
            ErrorStateView(message: L10n.State.fixtureErrorMessage) {
                Task { await viewModel.search() }
            }
        } else if viewModel.results.isEmpty && viewModel.googlePlaces.isEmpty {
            EmptyStateView(
                title: L10n.Search.emptyTitle,
                message: L10n.Search.emptyMessage,
                systemImage: "magnifyingglass"
            )
        } else {
            List {
                if !viewModel.googlePlaces.isEmpty {
                    Section(L10n.Search.googlePlacesSection) {
                        ForEach(viewModel.googlePlaces, id: \.placeID) { place in
                            GooglePlaceRow(place: place) {
                                submitPlace(place)
                            }
                        }
                    }
                }

                Section(L10n.Search.localResults) {
                    ForEach(viewModel.results) { result in
                        Button {
                            selectResult(result)
                        } label: {
                            SearchResultRow(result: result)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func submitPlace(_ place: GooglePlaceResult) {
        if !session.requireAuthentication(for: .account) {
            return
        }
        Task {
            do {
                _ = try await environment.contributionRepository.submitGym(
                    SubmitGymRequest(
                        idempotencyKey: IdempotencyKey(),
                        googlePlaceID: place.placeID,
                        name: place.name,
                        streetAddress: place.streetAddress,
                        suburb: parseSuburb(from: place.streetAddress) ?? place.name,
                        state: "",
                        postcode: nil,
                        latitude: place.latitude,
                        longitude: place.longitude
                    )
                )
            } catch {
                // Submission failed silently in the MVP; no user-facing error yet.
            }
        }
    }

    private func parseSuburb(from address: String?) -> String? {
        guard let address else { return nil }
        let components = address.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        return components.first
    }
}

private struct SearchResultRow: View {
    let result: LocalSearchResult

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(DesignColour.opticBlue)
            VStack(alignment: .leading) {
                Text(title).foregroundStyle(DesignColour.primaryText)
                Text(subtitle).font(.caption).foregroundStyle(DesignColour.secondaryText)
            }
        }
    }

    private var icon: String {
        switch result {
        case .gym: "building.2"
        case .wallZone: "square.stack.3d.up"
        case .route: "circle.hexagongrid"
        }
    }

    private var title: String {
        switch result {
        case .gym(let gym): gym.name
        case .wallZone(let zone, _): zone.name
        case .route(let route, _, _):
            "\(route.colour) · \(route.displayGrade?.displayName ?? String(localized: L10n.Grade.unknown))"
        }
    }

    private var subtitle: String {
        switch result {
        case .gym(let gym): gym.suburb
        case .wallZone(_, let gym): gym.name
        case .route(_, let zone, let gym): "\(gym.name) · \(zone.name)"
        }
    }
}

private struct GooglePlaceRow: View {
    let place: GooglePlaceResult
    let submit: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "building.2")
                .foregroundStyle(DesignColour.opticBlue)
            VStack(alignment: .leading) {
                Text(place.name).foregroundStyle(DesignColour.primaryText)
                if let address = place.streetAddress {
                    Text(address).font(.caption).foregroundStyle(DesignColour.secondaryText)
                }
            }
            Spacer()
            Button(L10n.Search.submitGym) { submit() }
                .buttonStyle(CompactActionButtonStyle())
        }
    }
}
