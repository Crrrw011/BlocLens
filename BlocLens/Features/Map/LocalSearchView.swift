import SwiftUI

struct LocalSearchView: View {
    let environment: AppEnvironment
    let selectResult: (LocalSearchResult) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: LocalSearchViewModel

    init(environment: AppEnvironment, selectResult: @escaping (LocalSearchResult) -> Void) {
        self.environment = environment
        self.selectResult = selectResult
        _viewModel = StateObject(
            wrappedValue: LocalSearchViewModel(
                gymRepository: environment.gymRepository,
                routeRepository: environment.routeRepository
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
        } else if viewModel.results.isEmpty {
            EmptyStateView(
                title: L10n.Search.emptyTitle,
                message: L10n.Search.emptyMessage,
                systemImage: "magnifyingglass"
            )
        } else {
            List(viewModel.results) { result in
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
            "\(route.colourOrTag) · \(route.officialGrade?.displayName ?? String(localized: L10n.Grade.unknown))"
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
