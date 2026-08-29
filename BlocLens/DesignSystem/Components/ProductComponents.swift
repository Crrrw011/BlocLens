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
        .font(BlocTypography.status)
        .padding(.horizontal, BlocSpacing.compact)
        .frame(minHeight: 28)
        .foregroundStyle(colour)
        .background(colour.opacity(0.12), in: Capsule())
        .overlay { Capsule().stroke(colour.opacity(0.25), lineWidth: 0.5) }
        .accessibilityElement(children: .combine)
    }
}

struct GradeChip: View {
    let grade: VGrade?
    let label: LocalizedStringResource

    var body: some View {
        VStack(alignment: .leading, spacing: BlocSpacing.xSmall) {
            Text(label).font(BlocTypography.caption).foregroundStyle(DesignColour.textSecondary)
            Text(grade?.displayName ?? String(localized: L10n.Grade.unknown))
                .font(BlocTypography.grade)
        }
        .padding(.horizontal, BlocSpacing.compact)
        .padding(.vertical, BlocSpacing.small)
        .background(DesignColour.surfaceElevated, in: RoundedRectangle(cornerRadius: BlocRadius.control, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: BlocRadius.control, style: .continuous).stroke(DesignColour.separator.opacity(0.5), lineWidth: 0.5) }
        .accessibilityElement(children: .combine)
    }
}

struct FacilityChip: View {
    let facility: GymFacility

    var body: some View {
        Label(L10n.facility(facility), systemImage: L10n.facilityIcon(facility))
            .font(.caption)
            .padding(.horizontal, DesignSpacing.compact)
            .frame(minHeight: 32)
            .background(DesignColour.surfaceElevated, in: Capsule())
            .overlay { Capsule().stroke(DesignColour.separator.opacity(0.45), lineWidth: 0.5) }
            .accessibilityElement(children: .combine)
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
        .foregroundStyle(DesignColour.textSecondary)
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
        LazyVGrid(columns: [GridItem(.flexible(), spacing: DesignSpacing.small), GridItem(.flexible())], spacing: DesignSpacing.small) {
            ForEach(LogbookStatus.allCases, id: \.self) { status in
                Button {
                    select(status)
                } label: {
                    HStack(spacing: DesignSpacing.small) {
                        Image(systemName: selection == status ? status.selectedSystemImage : status.systemImage)
                        Text(L10n.logbookStatus(status))
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(LogbookStatusButtonStyle(isSelected: selection == status))
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

private struct LogbookStatusButtonStyle: ButtonStyle {
    let isSelected: Bool
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isSelected ? Color.white : (isEnabled ? DesignColour.textPrimary : DesignColour.textTertiary))
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, DesignSpacing.small)
            .background(
                isSelected ? DesignColour.brandPrimary : DesignColour.surfacePrimary,
                in: RoundedRectangle(cornerRadius: DesignRadius.control, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: DesignRadius.control, style: .continuous)
                    .stroke(isSelected ? Color.clear : DesignColour.separator.opacity(0.6), lineWidth: 0.5)
            }
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

private extension LogbookStatus {
    var systemImage: String {
        switch self {
        case .wantToTry: "bookmark"
        case .projecting: "hammer"
        case .sent: "checkmark.circle"
        case .flash: "bolt"
        }
    }

    var selectedSystemImage: String {
        switch self {
        case .wantToTry: "bookmark.fill"
        case .projecting: "hammer.fill"
        case .sent: "checkmark.circle.fill"
        case .flash: "bolt.fill"
        }
    }
}
