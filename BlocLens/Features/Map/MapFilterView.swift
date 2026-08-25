import SwiftUI

struct MapFilterView: View {
    @Binding var options: GymFilterOptions
    let apply: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(L10n.MapFilter.openNow, isOn: $options.openNow)
                    Text(L10n.MapFilter.openNowNotice)
                        .font(.caption)
                        .foregroundStyle(DesignColour.secondaryText)
                }

                Section(L10n.Gym.facilities) {
                    ForEach([GymFacility.parking, .showers, .trainingBoard, .cafe], id: \.self) { facility in
                        Toggle(
                            L10n.facility(facility),
                            isOn: Binding(
                                get: { options.facilities.contains(facility) },
                                set: { selected in
                                    if selected { options.facilities.insert(facility) }
                                    else { options.facilities.remove(facility) }
                                }
                            )
                        )
                    }
                }

                Section {
                    Toggle(L10n.MapFilter.hasBeta, isOn: $options.hasBeta)
                    Toggle(L10n.MapFilter.recentlyReset, isOn: $options.recentlyReset)
                }

                Section {
                    Button(L10n.MapFilter.clear) { options = GymFilterOptions() }
                    Button(L10n.MapFilter.showResults) {
                        apply()
                        dismiss()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier("map-filter-show-results")
                }
            }
            .navigationTitle(L10n.MapFilter.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.cancel) { dismiss() }
                }
            }
        }
    }
}
