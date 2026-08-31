import Foundation
import SwiftUI

nonisolated struct GymNameDisplay: Equatable {
    let singleLine: String
    let firstLine: String
    let secondLine: String?
    let usesTwoLines: Bool

    static func from(gym: Gym) -> GymNameDisplay {
        // Must use structured fields, never string split
        let full = gym.name
        let brand = gym.brandName
        // Second line is suburb + state or branch name; use suburb as location
        let location = gym.suburb.isEmpty ? gym.state : "\(gym.suburb)"
        return GymNameDisplay(
            singleLine: full,
            firstLine: brand,
            secondLine: location,
            usesTwoLines: false
        )
    }
}

struct GymNameTitleView: View {
    let gym: Gym
    let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            GymNameTitleContent(gym: gym)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Open \(gym.name)"))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("gym-name-title")
        .frame(minHeight: 44, alignment: .leading)
    }
}

struct GymNameTitleContent: View {
    let gym: Gym
    var body: some View {
        ViewThatFits(in: .horizontal) {
            // Priority: single line full name
            Text(verbatim: gym.name)
                .font(.title2.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            // Fallback: two lines brand + location (uses structured fields)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: gym.brandName)
                    .font(.title2.weight(.bold))
                    .lineLimit(1)
                if !gym.suburb.isEmpty {
                    Text(verbatim: gym.suburb)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(DesignColour.textSecondary)
                        .lineLimit(1)
                }
            }
        }
        .foregroundStyle(DesignColour.textPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// Helper for tests to validate not using string split
enum GymNameDisplayHelper {
    static func twoLineFallback(gym: Gym) -> (String, String?) {
        (gym.brandName, gym.suburb)
    }
}
