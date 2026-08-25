import SwiftUI

struct StatusChip: View {
    let title: LocalizedStringResource
    let systemImage: String?
    let colour: Color

    var body: some View {
        Label {
            Text(title)
        } icon: {
            if let systemImage { Image(systemName: systemImage) }
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, DesignSpacing.small)
        .padding(.vertical, DesignSpacing.xSmall)
        .foregroundStyle(colour)
        .background(colour.opacity(0.12), in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

struct GradeChip: View {
    let grade: VGrade?
    let label: LocalizedStringResource

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(DesignColour.secondaryText)
            Text(grade?.displayName ?? String(localized: L10n.Grade.unknown))
                .font(.headline.monospacedDigit())
        }
        .padding(.horizontal, DesignSpacing.small)
        .padding(.vertical, DesignSpacing.xSmall)
        .background(DesignColour.surface, in: RoundedRectangle(cornerRadius: DesignRadius.small))
        .accessibilityElement(children: .combine)
    }
}

struct FacilityChip: View {
    let facility: GymFacility

    var body: some View {
        Label(L10n.facility(facility), systemImage: L10n.facilityIcon(facility))
            .font(.caption)
            .padding(.horizontal, DesignSpacing.small)
            .padding(.vertical, DesignSpacing.xSmall)
            .background(DesignColour.surface, in: Capsule())
    }
}

struct HelpfulCountView: View {
    let count: Int

    var body: some View {
        Label {
            Text(count, format: .number) + Text(L10n.Beta.helpfulSuffix)
        } icon: {
            Image(systemName: "hand.thumbsup")
        }
        .font(.caption.weight(.medium))
        .accessibilityElement(children: .combine)
    }
}

struct OfflineStateView: View {
    let hasCachedData: Bool

    var body: some View {
        EmptyStateView(
            title: L10n.State.offlineTitle,
            message: hasCachedData ? L10n.State.offlineCachedMessage : L10n.State.offlineNoCacheMessage,
            systemImage: "wifi.slash"
        )
    }
}

struct LogbookStatusControl: View {
    let selection: LogbookStatus?
    let isEnabled: Bool
    let select: (LogbookStatus) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DesignSpacing.small) {
            ForEach(LogbookStatus.allCases, id: \.self) { status in
                Button {
                    select(status)
                } label: {
                    HStack {
                        Image(systemName: selection == status ? "checkmark.circle.fill" : "circle")
                        Text(L10n.logbookStatus(status))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())
                .tint(selection == status ? DesignColour.opticBlue : DesignColour.secondaryText)
                .disabled(!isEnabled)
                .accessibilityValue(selection == status ? L10n.Common.selected : L10n.Common.notSelected)
                .accessibilityIdentifier("logbook-status-\(status.rawValue)")
            }
        }
    }
}

struct SectionTitle: View {
    let title: LocalizedStringResource

    var body: some View {
        Text(title)
            .font(.title3.bold())
            .foregroundStyle(DesignColour.primaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
