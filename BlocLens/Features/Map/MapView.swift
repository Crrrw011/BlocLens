import MapKit
import SwiftUI

struct MapView: View {
    let environment: AppEnvironment
    @ObservedObject var session: AppSession

    @StateObject private var viewModel: MapViewModel
    @State private var cameraPosition: MapCameraPosition
    @State private var path = NavigationPath()
    @State private var selectedGym: Gym?
    @State private var showsSearch = false
    @State private var showsFilters = false
    @State private var showsNearbyMessage = false

    init(environment: AppEnvironment, session: AppSession) {
        self.environment = environment
        self.session = session
        _viewModel = StateObject(
            wrappedValue: MapViewModel(
                repository: environment.gymRepository,
                scenario: environment.scenario
            )
        )
        let brisbane = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: -27.47, longitude: 153.02),
            span: MKCoordinateSpan(latitudeDelta: 0.16, longitudeDelta: 0.16)
        )
        _cameraPosition = State(initialValue: .region(brisbane))
    }

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationTitle(L10n.Map.title)
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button {
                            showsSearch = true
                        } label: {
                            Label(L10n.Search.title, systemImage: "magnifyingglass")
                        }
                        .accessibilityIdentifier("map-search-button")

                        Button {
                            showsFilters = true
                        } label: {
                            Label(L10n.MapFilter.title, systemImage: viewModel.filterOptions.isActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        }
                        .accessibilityIdentifier("map-filter-button")

                        Button {
                            showsNearbyMessage = true
                        } label: {
                            Label(L10n.Map.nearbyGyms, systemImage: "location")
                        }
                    }
                }
                .navigationDestination(for: Gym.self) { gym in
                    GymDetailView(gym: gym, environment: environment, session: session)
                }
                .navigationDestination(for: WallZone.self) { zone in
                    WallZoneRouteListView(wallZone: zone, environment: environment, session: session)
                }
                .navigationDestination(for: ClimbingRoute.self) { route in
                    RouteDetailView(route: route, environment: environment, session: session)
                }
        }
        .task { await viewModel.load() }
        .sheet(isPresented: $showsSearch) {
            LocalSearchView(environment: environment) { result in
                showsSearch = false
                switch result {
                case .gym(let gym):
                    path.append(gym)
                case .wallZone(let zone, let gym):
                    path.append(gym)
                    path.append(zone)
                case .route(let route, let zone, let gym):
                    path.append(gym)
                    path.append(zone)
                    path.append(route)
                }
            }
        }
        .sheet(isPresented: $showsFilters) {
            MapFilterView(options: $viewModel.filterOptions) {
                viewModel.applyFilters()
            }
        }
        .alert(L10n.Map.locationUnavailableTitle, isPresented: $showsNearbyMessage) {
            Button(L10n.Common.ok, role: .cancel) {}
        } message: {
            Text(L10n.Map.locationUnavailableMessage)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .initial, .loading:
            LoadingStateView()
        case .loaded(let gyms):
            mapContent(gyms: gyms, isOffline: false)
        case .offlineWithCache(let gyms):
            mapContent(gyms: gyms, isOffline: true)
        case .empty:
            EmptyStateView(
                title: L10n.Map.emptyFixtureTitle,
                message: L10n.Map.emptyFixtureMessage,
                systemImage: "map"
            )
        case .error:
            ErrorStateView(message: L10n.State.fixtureErrorMessage) {
                Task { await viewModel.load() }
            }
        case .offlineWithoutCache:
            EmptyStateView(
                title: L10n.State.offlineTitle,
                message: L10n.State.offlineNoCacheMessage,
                systemImage: "wifi.slash"
            )
        }
    }

    private func mapContent(gyms: [Gym], isOffline: Bool) -> some View {
        Map(position: $cameraPosition) {
            ForEach(gyms) { gym in
                Annotation(gym.name, coordinate: CLLocationCoordinate2D(
                    latitude: gym.coordinate.latitude,
                    longitude: gym.coordinate.longitude
                )) {
                    Button {
                        selectedGym = gym
                    } label: {
                        Image(systemName: "mountain.2.circle.fill")
                            .font(.title)
                            .foregroundStyle(DesignColour.opticBlue)
                            .background(.regularMaterial, in: Circle())
                    }
                    .accessibilityLabel(gym.name)
                    .accessibilityIdentifier("gym-annotation-\(gym.id.rawValue)")
                }
            }
        }
        .mapStyle(.standard)
        .overlay(alignment: .top) {
            if isOffline {
                Label(L10n.State.offlineCachedMessage, systemImage: "wifi.slash")
                    .font(.caption)
                    .padding(DesignSpacing.small)
                    .background(.regularMaterial, in: Capsule())
                    .padding(DesignSpacing.small)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let selectedGym {
                GymPreviewCard(
                    gym: selectedGym,
                    openGym: { path.append(selectedGym) },
                    close: { self.selectedGym = nil }
                )
                .padding(.horizontal, DesignSpacing.medium)
                .padding(.bottom, DesignSpacing.small)
            }
        }
    }
}

private struct GymPreviewCard: View {
    let gym: Gym
    let openGym: () -> Void
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.small) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: DesignSpacing.xSmall) {
                    HStack {
                        Text(gym.name).font(.headline)
                        if gym.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(DesignColour.opticBlue)
                                .accessibilityLabel(L10n.Gym.verified)
                        }
                    }
                    Text(gym.suburb)
                        .font(.subheadline)
                        .foregroundStyle(DesignColour.secondaryText)
                }
                Spacer()
                Button(action: close) {
                    Image(systemName: "xmark.circle.fill")
                }
                .accessibilityLabel(L10n.Common.close)
                .accessibilityIdentifier("gym-preview-close")
            }

            HStack(spacing: DesignSpacing.medium) {
                Label("\(gym.betaCount)", systemImage: "link")
                if let reset = gym.latestResetDate {
                    Label(reset.formatted(date: .abbreviated, time: .omitted), systemImage: "arrow.clockwise")
                }
                Text(L10n.hardSoft(gym.overallHardSoftSummary))
            }
            .font(.caption)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSpacing.xSmall) {
                    ForEach(gym.facilities.prefix(3), id: \.self) { facility in
                        FacilityChip(facility: facility)
                    }
                }
            }

            Button(L10n.Gym.viewGym, action: openGym)
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityIdentifier("open-gym-button")
        }
        .cardStyle()
        .background(DesignColour.background.opacity(0.01))
    }
}

#Preview("Map — Loaded") {
    let environment = AppEnvironment.development()
    MapView(environment: environment, session: AppSession(environment: environment))
}

#Preview("Map — Empty") {
    let environment = AppEnvironment.development(scenario: .empty)
    MapView(environment: environment, session: AppSession(environment: environment))
}

#Preview("Map — Offline") {
    let environment = AppEnvironment.development(scenario: .offlineWithCache)
    MapView(environment: environment, session: AppSession(environment: environment))
}
