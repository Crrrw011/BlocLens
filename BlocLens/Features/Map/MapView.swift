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
                dataAvailability: environment.dataAvailability
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
            LocalSearchView(environment: environment, session: session) { result in
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
            VStack(spacing: DesignSpacing.medium) {
                EmptyStateView(title: L10n.Map.emptyFixtureTitle, message: L10n.Map.emptyFixtureMessage, systemImage: "map")
                if viewModel.filterOptions.isActive {
                    Button(L10n.MapFilter.clear) { viewModel.clearFilters() }
                        .buttonStyle(SecondaryButtonStyle())
                        .padding(.horizontal, DesignSpacing.large)
                }
            }
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
                        Image(systemName: selectedGym?.id == gym.id ? "mountain.2.circle.fill" : "mountain.2.circle")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(selectedGym?.id == gym.id ? .white : DesignColour.brandPrimary)
                            .frame(width: 44, height: 44)
                            .background(selectedGym?.id == gym.id ? DesignColour.brandPrimary : DesignColour.surfaceElevated, in: Circle())
                            .overlay { Circle().stroke(DesignColour.brandPrimary.opacity(0.55), lineWidth: selectedGym?.id == gym.id ? 2 : 1) }
                            .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                    }
                    .accessibilityLabel(gym.name)
                    .accessibilityIdentifier("gym-annotation-\(gym.id.rawValue)")
                }
            }
        }
        .mapStyle(.standard)
        .safeAreaInset(edge: .top) {
            VStack(spacing: DesignSpacing.small) {
                if isOffline { OfflineBanner(message: L10n.State.offlineCachedMessage) }
                HStack(spacing: DesignSpacing.small) {
                    Button { showsSearch = true } label: { Image(systemName: "magnifyingglass") }
                        .buttonStyle(IconButtonStyle())
                        .accessibilityLabel(L10n.Search.title)
                        .accessibilityIdentifier("map-search-button")
                    FilterPill(title: L10n.MapFilter.title, activeCount: viewModel.filterOptions.activeCount) {
                        showsFilters = true
                    }
                    .accessibilityIdentifier("map-filter-button")
                    Spacer(minLength: 0)
                    Button { showsNearbyMessage = true } label: { Image(systemName: "location") }
                        .buttonStyle(IconButtonStyle())
                        .accessibilityLabel(L10n.Map.nearbyGyms)
                }
                .padding(DesignSpacing.small)
                .adaptiveGlass(interactive: true)
            }
            .padding(.horizontal, DesignSpacing.medium)
            .padding(.top, DesignSpacing.small)
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
        VStack(alignment: .leading, spacing: DesignSpacing.compact) {
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

            ViewThatFits(in: .horizontal) {
                previewMetadata
                VStack(alignment: .leading, spacing: DesignSpacing.small) { previewMetadata }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSpacing.xSmall) {
                    ForEach(gym.facilities.prefix(3), id: \.self) { facility in
                        FacilityChip(facility: facility)
                    }
                }
            }

            Button(action: openGym) {
                Label(L10n.Gym.viewGym, systemImage: "arrow.right")
            }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityIdentifier("open-gym-button")
        }
        .padding(DesignSpacing.medium)
        .adaptiveGlass(interactive: true)
    }

    private var previewMetadata: some View {
        HStack(spacing: DesignSpacing.compact) {
            Label("\(gym.betaCount)", systemImage: "link")
            if let reset = gym.latestResetDate {
                Label(reset.formatted(.relative(presentation: .named)), systemImage: "arrow.clockwise")
            }
            Label(L10n.hardSoft(gym.overallHardSoftSummary), systemImage: "dial.medium")
        }
        .font(DesignTypography.caption)
        .foregroundStyle(DesignColour.textSecondary)
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
