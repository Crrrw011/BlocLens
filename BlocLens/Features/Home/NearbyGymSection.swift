import SwiftUI
import MapKit
import CoreLocation
import Combine

@MainActor
final class NearbyLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var userLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = manager.authorizationStatus
    }

    func requestLocation() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            break
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        userLocation = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Keep last known location or nil
    }
}

struct NearbyGymSection: View {
    let environment: AppEnvironment
    @StateObject private var locationManager = NearbyLocationManager()
    @State private var gyms: [Gym] = []
    @State private var isLoading = true

    private var nearestGym: Gym? {
        guard let userLoc = locationManager.userLocation else { return gyms.first }
        return gyms.min(by: { a, b in
            let locA = CLLocation(latitude: a.coordinate.latitude, longitude: a.coordinate.longitude)
            let locB = CLLocation(latitude: b.coordinate.latitude, longitude: b.coordinate.longitude)
            return userLoc.distance(from: locA) < userLoc.distance(from: locB)
        })
    }

    private var distanceText: String? {
        guard let userLoc = locationManager.userLocation, let gym = nearestGym else { return nil }
        let gymLoc = CLLocation(latitude: gym.coordinate.latitude, longitude: gym.coordinate.longitude)
        let meters = userLoc.distance(from: gymLoc)
        if meters < 1000 {
            return String(format: "%.0f m away", meters)
        } else {
            return String(format: "%.1f km away", meters / 1000)
        }
    }

    private var mapCamera: MapCameraPosition {
        guard let gym = nearestGym else {
            return .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: -27.4705, longitude: 153.0260), span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)))
        }
        if let userLoc = locationManager.userLocation {
            let gymCoord = CLLocationCoordinate2D(latitude: gym.coordinate.latitude, longitude: gym.coordinate.longitude)
            let centerLat = (userLoc.coordinate.latitude + gymCoord.latitude) / 2
            let centerLon = (userLoc.coordinate.longitude + gymCoord.longitude) / 2
            let latDelta = abs(userLoc.coordinate.latitude - gymCoord.latitude) * 2.2 + 0.02
            let lonDelta = abs(userLoc.coordinate.longitude - gymCoord.longitude) * 2.2 + 0.02
            return .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon), span: MKCoordinateSpan(latitudeDelta: max(latDelta, 0.02), longitudeDelta: max(lonDelta, 0.02))))
        } else {
            return .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: gym.coordinate.latitude, longitude: gym.coordinate.longitude), span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.small) {
            Label("Your nearby Bouldering Gym", systemImage: "location.circle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DesignColour.textPrimary)

            if isLoading {
                RoundedRectangle(cornerRadius: 12).fill(Color(uiColor: .secondarySystemBackground))
                    .frame(height: 180)
                    .overlay { ProgressView() }
            } else if let gym = nearestGym {
                Map(position: .constant(mapCamera), interactionModes: []) {
                    if let userLoc = locationManager.userLocation {
                        Annotation("You", coordinate: userLoc.coordinate) {
                            ZStack {
                                Circle().fill(BlocColor.opticBlue).frame(width: 16, height: 16)
                                Circle().stroke(.white, lineWidth: 2).frame(width: 16, height: 16)
                            }
                        }
                    }
                    Annotation(gym.name, coordinate: CLLocationCoordinate2D(latitude: gym.coordinate.latitude, longitude: gym.coordinate.longitude)) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.red)
                            .background(Circle().fill(.white))
                    }
                }
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(DesignColour.separator.opacity(0.3), lineWidth: 0.5) }
                .allowsHitTesting(false)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(gym.name).font(.subheadline.weight(.semibold)).foregroundStyle(DesignColour.textPrimary).lineLimit(1)
                        Text("\(gym.suburb), \(gym.state)").font(.caption).foregroundStyle(DesignColour.textSecondary)
                    }
                    Spacer()
                    if let dist = distanceText {
                        Text(dist).font(.caption.weight(.medium)).foregroundStyle(BlocColor.opticBlue)
                    }
                }
                .padding(.horizontal, 4)
            } else {
                Text("No gyms found nearby").font(.caption).foregroundStyle(DesignColour.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }

            if locationManager.authorizationStatus == .denied {
                Text("Location access denied. Enable in Settings to see nearby gyms.")
                    .font(.caption2).foregroundStyle(DesignColour.textTertiary)
            }
        }
        .padding(DesignSpacing.small)
        .background(Color(uiColor: .tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(DesignColour.separator.opacity(0.3), lineWidth: 0.5) }
        .task {
            await loadGyms()
            locationManager.requestLocation()
        }
    }

    private func loadGyms() async {
        isLoading = true
        defer { isLoading = false }
        do {
            gyms = try await environment.gymRepository.allGyms()
        } catch {
            gyms = []
        }
    }
}
