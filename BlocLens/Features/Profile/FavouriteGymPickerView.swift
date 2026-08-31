import SwiftUI
import MapKit

struct FavouriteGymPickerView: View {
    let environment: AppEnvironment
    @Binding var selectedGymID: GymID?
    var onSelect: ((Gym) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var gyms: [Gym] = []
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var selectedGym: Gym?
    @State private var cameraPosition = MapCameraPosition.region(
        MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: -27.4705, longitude: 153.0260), span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5))
    )

    private var filteredGyms: [Gym] {
        if searchText.isEmpty { return gyms }
        return gyms.filter { $0.name.localizedCaseInsensitiveContains(searchText) || $0.suburb.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    mapSection
                    listSection
                }
            }
            .navigationTitle("Select Favourite Gym")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm") {
                        if let gym = selectedGym {
                            selectedGymID = gym.id
                            onSelect?(gym)
                        }
                        dismiss()
                    }
                    .disabled(selectedGym == nil)
                }
            }
        }
        .task { await loadGyms() }
        .onChange(of: selectedGym) { _, newValue in
            if let gym = newValue {
                cameraPosition = MapCameraPosition.region(
                    MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: gym.coordinate.latitude, longitude: gym.coordinate.longitude), span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
                )
            }
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search gyms", text: $searchText)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button { searchText = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
            }
        }
        .padding(10)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        .padding()
    }

    private var mapSection: some View {
        Map(position: $cameraPosition) {
            ForEach(filteredGyms) { gym in
                Annotation(gym.name, coordinate: CLLocationCoordinate2D(latitude: gym.coordinate.latitude, longitude: gym.coordinate.longitude)) {
                    Button {
                        selectedGym = gym
                    } label: {
                        Image(systemName: selectedGym?.id == gym.id ? "mappin.circle.fill" : "mappin.circle")
                            .font(.title2)
                            .foregroundStyle(selectedGym?.id == gym.id ? BlocColor.opticBlue : .red)
                            .background(Circle().fill(.white))
                    }
                }
            }
        }
        .frame(height: 250)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private var listSection: some View {
        List(filteredGyms, id: \.id) { gym in
            Button {
                selectedGym = gym
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(gym.name).font(.body.weight(.semibold)).foregroundStyle(.primary)
                        Text("\(gym.suburb), \(gym.state)").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if selectedGym?.id == gym.id {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(BlocColor.opticBlue)
                    } else if selectedGymID == gym.id {
                        Image(systemName: "checkmark").foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .listRowBackground(selectedGym?.id == gym.id ? Color(uiColor: .secondarySystemBackground) : Color.clear)
        }
        .listStyle(.plain)
    }

    private func loadGyms() async {
        isLoading = true
        defer { isLoading = false }
        do {
            gyms = try await environment.gymRepository.allGyms()
            if let current = selectedGymID, let gym = gyms.first(where: { $0.id == current }) {
                selectedGym = gym
            }
        } catch {
            gyms = []
        }
    }
}

#Preview {
    FavouriteGymPickerView(environment: .development(), selectedGymID: .constant(nil))
}
