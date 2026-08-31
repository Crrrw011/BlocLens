import MapKit
import SwiftUI

struct MapView: View {
    let environment: AppEnvironment
    @ObservedObject var session: AppSession

    @StateObject private var viewModel: MapViewModel
    @StateObject private var locationService = LocationService()
    @State private var cameraPosition: MapCameraPosition
    @State private var path = NavigationPath()
    @State private var selectedGym: Gym?
    @State private var showsSearch = false
    @State private var showsFilters = false
    @State private var showsLocationDeniedAlert = false
    @State private var showsLocationErrorAlert = false
    @State private var pendingMyLocation = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        .task(id: session.authenticationState.isSignedIn) {
            await viewModel.load()
        }
        .task {
            locationService.requestAuthorizationIfNeeded()
        }
        .alert("Location Access Needed", isPresented: $showsLocationDeniedAlert) {
            Button("Open Settings") { locationService.openAppSettings() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please enable location access in Settings to use My Location.")
        }
        .alert("Location Error", isPresented: $showsLocationErrorAlert) {
            Button("Try again") { locationService.requestLocation() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(locationService.errorMessage ?? "Unable to get your location. Please try again.")
        }
        .onReceive(locationService.$authorizationState) { state in
            if state == .denied || state == .restricted {
                showsLocationDeniedAlert = true
            } else if state == .authorized {
                // If we were waiting for location after a tap, the userLocation change will handle camera
            }
        }
        .onReceive(locationService.$userLocation) { loc in
            if let loc, pendingMyLocation, locationService.authorizationState == .authorized {
                moveCameraToInclude(userLocation: loc)
                pendingMyLocation = false
            }
        }
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
                        ZStack {
                            Circle().fill(.white).frame(width: 36, height: 36).shadow(color: .black.opacity(0.15), radius: 3, y: 1)
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(.red)
                                .overlay {
                                    if selectedGym?.id == gym.id {
                                        Circle().stroke(BlocColor.opticBlue, lineWidth: 2).frame(width: 36, height: 36)
                                    }
                                }
                        }
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                    }
                    .accessibilityLabel(gym.name)
                    .accessibilityIdentifier("gym-annotation-\(gym.id.rawValue)")
                }
            }
        }
        .mapStyle(.standard)
        .safeAreaInset(edge: .top) {
            if isOffline {
                OfflineBanner(message: L10n.State.offlineCachedMessage)
                    .padding(.horizontal, DesignSpacing.medium)
                    .padding(.top, DesignSpacing.small)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: DesignSpacing.small) {
                if let selectedGym {
                    GymPreviewCard(
                        gym: selectedGym,
                        openGym: { path.append(selectedGym) },
                        close: { self.selectedGym = nil }
                    )
                }
                bottomControlBar
            }
            .padding(.horizontal, DesignSpacing.medium)
            .padding(.bottom, DesignSpacing.small)
        }
    }

    // MARK: - Bottom control bar — Filters | Search | My Location

    private var bottomControlBar: some View {
        HStack(spacing: DesignSpacing.small) {
            Button { showsFilters = true } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.body.weight(.medium))
            }
            .buttonStyle(IconButtonStyle())
            .accessibilityLabel("Filters")
            .accessibilityIdentifier("map-filter-button")

            Button { showsSearch = true } label: {
                HStack(spacing: DesignSpacing.small) {
                    Image(systemName: "magnifyingglass")
                        .font(.subheadline.weight(.semibold))
                    Text(L10n.Search.prompt)
                        .font(DesignTypography.supporting)
                        .lineLimit(1)
                }
                .foregroundStyle(DesignColour.textSecondary)
                .padding(.horizontal, DesignSpacing.compact)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color(uiColor: .systemBackground), in: Capsule())
                .overlay { Capsule().stroke(Color.black.opacity(0.08), lineWidth: 0.5) }
                .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.Search.title)
            .accessibilityIdentifier("map-search-button")

            Button { handleMyLocationTap() } label: {
                Image(systemName: "location.fill")
                    .font(.body.weight(.medium))
            }
            .buttonStyle(IconButtonStyle())
            .accessibilityLabel("My Location")
            .accessibilityIdentifier("map-my-location-button")
        }
        .padding(DesignSpacing.small)
        .blocGlass(interactive: true)
    }

    private func handleMyLocationTap() {
        let state = locationService.authorizationState
        switch state {
        case .notDetermined:
            pendingMyLocation = true
            locationService.requestAuthorizationIfNeeded()
        case .authorized:
            if let loc = locationService.userLocation {
                moveCameraToInclude(userLocation: loc)
                pendingMyLocation = false
            } else {
                pendingMyLocation = true
                locationService.requestLocation()
            }
        case .denied, .restricted:
            showsLocationDeniedAlert = true
        case .transientError:
            showsLocationErrorAlert = true
        }
    }

    private func moveCameraToInclude(userLocation: CLLocation) {
        guard let nearest = nearestGym(to: userLocation) else { return }
        let gymCoord = CLLocationCoordinate2D(latitude: nearest.coordinate.latitude, longitude: nearest.coordinate.longitude)
        let userCoord = userLocation.coordinate
        let centerLat = (userCoord.latitude + gymCoord.latitude) / 2
        let centerLon = (userCoord.longitude + gymCoord.longitude) / 2
        let latDelta = abs(userCoord.latitude - gymCoord.latitude) * 2.4 + 0.02
        let lonDelta = abs(userCoord.longitude - gymCoord.longitude) * 2.4 + 0.02
        let region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon), span: MKCoordinateSpan(latitudeDelta: max(latDelta, 0.02), longitudeDelta: max(lonDelta, 0.02)))
        let newPosition: MapCameraPosition = .region(region)
        if reduceMotion {
            cameraPosition = newPosition
        } else {
            withAnimation(.easeInOut(duration: 0.6)) { cameraPosition = newPosition }
        }
    }

    private func nearestGym(to location: CLLocation) -> Gym? {
        guard case .loaded(let gyms) = viewModel.state else { return nil }
        return gyms.min(by: { a, b in
            let la = CLLocation(latitude: a.coordinate.latitude, longitude: a.coordinate.longitude)
            let lb = CLLocation(latitude: b.coordinate.latitude, longitude: b.coordinate.longitude)
            return location.distance(from: la) < location.distance(from: lb)
        })
    }
}

private struct GymPreviewCard: View {
    let gym: Gym
    let openGym: () -> Void
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.compact) {
            HStack(alignment: .top, spacing: DesignSpacing.small) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: DesignSpacing.xSmall) {
                        Text(verbatim: gym.name)
                            .font(.headline)
                            .foregroundStyle(DesignColour.textPrimary)
                            .lineLimit(1)
                        if gym.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(BlocColor.opticBlue)
                                .font(.caption)
                                .accessibilityLabel(L10n.Gym.verified)
                        }
                    }
                    HStack(spacing: 4) {
                        Label(gym.brandName, systemImage: "building.2")
                        Text(verbatim: "·").foregroundStyle(DesignColour.textTertiary)
                        Text(verbatim: "\(gym.suburb), \(gym.state)")
                        if gym.betaCount > 0 {
                            Text(verbatim: "·").foregroundStyle(DesignColour.textTertiary)
                            Label("\(gym.betaCount)", systemImage: "link")
                        }
                    }
                    .font(BlocTypography.caption)
                    .foregroundStyle(DesignColour.textSecondary)
                    .lineLimit(1)
                }
                Spacer(minLength: DesignSpacing.small)
                Button(action: close) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(DesignColour.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.Common.close)
                .accessibilityIdentifier("gym-preview-close")
            }

            Text(verbatim: previewMetadataText)
                .font(BlocTypography.metadata)
                .foregroundStyle(DesignColour.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)

            if !gym.facilities.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignSpacing.xSmall) {
                        ForEach(gym.facilities.prefix(3), id: \.self) { facility in
                            FacilityChip(facility: facility)
                        }
                    }
                }
            }

            HStack {
                Spacer()
                Button(action: openGym) {
                    Label(L10n.Gym.viewGym, systemImage: "arrow.right")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(CompactActionButtonStyle())
                .accessibilityIdentifier("open-gym-button")
            }
        }
        .padding(DesignSpacing.medium)
        .blocGlass(interactive: true)
    }

    private var previewMetadataText: String {
        let zones = gym.wallZoneIDs.count
        let beta = gym.betaCount
        let hardSoft = String(localized: L10n.hardSoft(gym.overallHardSoftSummary))
        if let reset = gym.latestResetDate {
            let rel = reset.formatted(.relative(presentation: .named))
            return "\(zones) zones · \(beta) beta · \(hardSoft) · \(rel)"
        }
        return "\(zones) zones · \(beta) beta · \(hardSoft)"
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
