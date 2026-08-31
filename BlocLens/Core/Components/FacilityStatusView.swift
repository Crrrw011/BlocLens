import SwiftUI

enum FacilityAvailability: String, Equatable, Sendable {
    case available
    case unavailable
    case unknown
}

struct FacilityStatus: Equatable, Sendable {
    let facility: GymFacility
    let availability: FacilityAvailability
}

enum FacilityStatusProvider {
    // Maps gym facilities to availability for the 3 primary facilities, but supports all
    static func statuses(for gym: Gym) -> [FacilityStatus] {
        // For Unknown: if gym facilities is empty we could treat as unknown? But spec says if model supports unknown, don't fake unavailable.
        // Our Gym model does not have explicit unknown; we infer: if gym has no facility data? In fixtures all have facilities.
        // We treat facilities present => available, missing => unavailable, except if we explicitly have unknown marker (future).
        // For now, support unknown via a separate check: if gym has no facilities at all? Not used.
        let known: [GymFacility] = [.parking, .cafe, .showers]
        // Also include any extra facilities from gym to avoid overflow – but limit display to 3 primary + extra up to 6 total, sorted
        var result: [FacilityStatus] = []
        for facility in known {
            let availability: FacilityAvailability = gym.facilities.contains(facility) ? .available : .unavailable
            result.append(FacilityStatus(facility: facility, availability: availability))
        }
        // Add remaining facilities beyond the 3 primary if they are available (to show extra without overflow)
        let extra = gym.facilities.filter { !known.contains($0) }
        for facility in extra.prefix(3) {
            result.append(FacilityStatus(facility: facility, availability: .available))
        }
        return result
    }

    static func status(for facility: GymFacility, in gym: Gym, unknownFacilities: Set<GymFacility> = []) -> FacilityAvailability {
        if unknownFacilities.contains(facility) { return .unknown }
        return gym.facilities.contains(facility) ? .available : .unavailable
    }
}

struct FacilityIconView: View {
    let status: FacilityStatus

    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)
                .frame(width: 32, height: 32)
                .overlay { Circle().stroke(borderColor, lineWidth: 1) }
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(foregroundColor)
            // Auxiliary checkmark/xmark/questionmark overlay at bottom trailing
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Image(systemName: auxiliaryIcon)
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(auxiliaryColor)
                        .frame(width: 12, height: 12)
                        .background(Circle().fill(Color(uiColor: .systemBackground)))
                        .overlay { Circle().stroke(borderColor, lineWidth: 0.5) }
                        .offset(x: 2, y: 2)
                }
            }
            .frame(width: 32, height: 32)
        }
        .frame(width: 44, height: 44) // Ensure 44pt touch target (but not a button)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(facilityLabel)
        .accessibilityIdentifier("facility-\(status.facility.rawValue)-\(status.availability.rawValue)")
    }

    private var backgroundColor: Color {
        switch status.availability {
        case .available: DesignColour.success.opacity(0.12)
        case .unavailable: DesignColour.error.opacity(0.12)
        case .unknown: DesignColour.offline.opacity(0.12)
        }
    }

    private var borderColor: Color {
        switch status.availability {
        case .available: DesignColour.success
        case .unavailable: DesignColour.error
        case .unknown: DesignColour.offline
        }
    }

    private var foregroundColor: Color {
        switch status.availability {
        case .available: DesignColour.success
        case .unavailable: DesignColour.error
        case .unknown: DesignColour.offline
        }
    }

    private var iconName: String {
        L10n.facilityIcon(status.facility)
    }

    private var auxiliaryIcon: String {
        switch status.availability {
        case .available: "checkmark"
        case .unavailable: "xmark"
        case .unknown: "questionmark"
        }
    }

    private var auxiliaryColor: Color {
        switch status.availability {
        case .available: DesignColour.success
        case .unavailable: DesignColour.error
        case .unknown: DesignColour.offline
        }
    }

    private var facilityLabel: Text {
        let base: String
        switch status.facility {
        case .parking: base = "Parking"
        case .cafe: base = "Café"
        case .showers: base = "Showers"
        case .trainingBoard: base = "Training Board"
        case .lockers: base = "Lockers"
        case .accessibleEntry: base = "Accessible Entry"
        }
        let avail: String
        switch status.availability {
        case .available: avail = "available"
        case .unavailable: avail = "unavailable"
        case .unknown: avail = "unknown"
        }
        // Special case for showers unknown wording per spec
        if status.facility == .showers && status.availability == .unknown {
            return Text("Shower availability unknown")
        }
        return Text("\(base) \(avail)")
    }
}

struct FacilityIconsRow: View {
    let gym: Gym
    var unknownFacilities: Set<GymFacility> = []

    var body: some View {
        HStack(spacing: 4) {
            ForEach(statuses, id: \.facility) { status in
                FacilityIconView(status: status)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("facility-icons-row")
    }

    private var statuses: [FacilityStatus] {
        if unknownFacilities.isEmpty {
            return FacilityStatusProvider.statuses(for: gym)
        } else {
            // Custom unknown handling
            let known: [GymFacility] = [.parking, .cafe, .showers]
            return known.map { fac in
                FacilityStatus(facility: fac, availability: FacilityStatusProvider.status(for: fac, in: gym, unknownFacilities: unknownFacilities))
            }
        }
    }
}

#Preview("Facilities Available") {
    let gym = DevelopmentFixtures.gyms[0]
    FacilityIconsRow(gym: gym)
        .padding()
}

#Preview("Facilities Unavailable") {
    let gym = Gym(id: "test", name: "Test", brandName: "Test", coordinate: GeoCoordinate(latitude: 0, longitude: 0), suburb: "Sub", state: "QLD", isVerified: false, betaCount: 0, latestResetDate: nil, overallHardSoftSummary: .balanced, facilities: [], wallZoneIDs: [], operatingSummary: .developmentFixture, dataSourceState: .developmentFixture, googlePlaceID: nil)
    FacilityIconsRow(gym: gym)
        .padding()
}

#Preview("Facilities Unknown") {
    let gym = DevelopmentFixtures.gyms[0]
    FacilityIconsRow(gym: gym, unknownFacilities: [.showers])
        .padding()
}
