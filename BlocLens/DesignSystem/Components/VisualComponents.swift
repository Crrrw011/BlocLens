import SwiftUI

struct SectionHeader: View {
    let title: LocalizedStringResource
    var supportingText: LocalizedStringResource?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.xSmall) {
            Text(title)
                .font(DesignTypography.sectionTitle)
                .foregroundStyle(DesignColour.textPrimary)
            if let supportingText {
                Text(supportingText)
                    .font(DesignTypography.supporting)
                    .foregroundStyle(DesignColour.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct OfflineBanner: View {
    let message: LocalizedStringResource

    var body: some View {
        Label(message, systemImage: "wifi.slash")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(DesignColour.textPrimary)
            .padding(.horizontal, DesignSpacing.compact)
            .frame(minHeight: 44)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignColour.offline.opacity(0.14), in: RoundedRectangle(cornerRadius: DesignRadius.control))
            .accessibilityElement(children: .combine)
    }
}

struct MetricCard: View {
    let title: LocalizedStringResource
    let value: String
    let systemImage: String
    var emphasized = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.small) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DesignColour.textSecondary)
            Text(value)
                .font(emphasized ? DesignTypography.numericStatistic : DesignTypography.gradeEmphasis)
                .foregroundStyle(emphasized ? DesignColour.brandPrimary : DesignColour.textPrimary)
                .minimumScaleFactor(0.8)
        }
        .cardStyle(elevated: emphasized)
        .accessibilityElement(children: .combine)
    }
}

struct GymSummaryCard: View {
    let gym: Gym
    var showsFacilities = true

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.compact) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: DesignSpacing.xSmall) {
                    HStack {
                        Text(gym.name).font(.title3.weight(.bold))
                        if gym.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(DesignColour.brandPrimary)
                                .accessibilityLabel(L10n.Gym.verified)
                        }
                    }
                    Text(gym.suburb)
                        .font(DesignTypography.supporting)
                        .foregroundStyle(DesignColour.textSecondary)
                }
                Spacer(minLength: DesignSpacing.small)
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(DesignColour.textTertiary)
            }

            ViewThatFits(in: .horizontal) {
                metadata
                VStack(alignment: .leading, spacing: DesignSpacing.small) { metadata }
            }

            if showsFacilities, !gym.facilities.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignSpacing.xSmall) {
                        ForEach(gym.facilities.prefix(4), id: \.self) { FacilityChip(facility: $0) }
                    }
                }
            }
        }
        .cardStyle(elevated: true)
        .accessibilityElement(children: .combine)
    }

    private var metadata: some View {
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

struct FilterPill: View {
    let title: LocalizedStringResource
    let activeCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSpacing.xSmall) {
                Image(systemName: activeCount > 0 ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                Text(title)
                if activeCount > 0 {
                    Text(activeCount, format: .number)
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .foregroundStyle(.white)
                        .background(DesignColour.brandPrimary, in: Capsule())
                }
            }
        }
        .buttonStyle(CompactActionButtonStyle())
        .accessibilityValue(activeCount > 0 ? L10n.Filter.active : L10n.Filter.inactive)
    }
}

struct RouteColourSwatch: View {
    let colourOrTag: String
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            shapeView.overlay { shapeStroke }
            Text(String(colourOrTag.prefix(1)).uppercased())
                .font(.caption.bold())
                .foregroundStyle(textColour)
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel(
            Text(L10n.Route.colourAccessibilityPrefix)
                + Text(verbatim: " \(RouteColourPresentation.accessibilityLabel(for: colourOrTag))")
        )
    }

    private var normalised: String { colourOrTag.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }

    private var token: BlocColor.HoldColor {
        if let exact = BlocColor.routePalette.first(where: { $0.name.lowercased() == normalised }) { return exact }
        if let partial = BlocColor.routePalette.first(where: { normalised.contains($0.name.lowercased()) }) { return partial }
        return BlocColor.grey
    }

    private var routeColour: Color { token.color }
    private var textColour: Color { token.textColor }

    @ViewBuilder
    private var shapeView: some View {
        switch token.shape {
        case .circle:
            Circle().fill(routeColour)
        case .square:
            RoundedRectangle(cornerRadius: 6, style: .continuous).fill(routeColour)
        case .diamond:
            RoundedRectangle(cornerRadius: 4, style: .continuous).fill(routeColour).rotationEffect(.degrees(45)).padding(4)
        }
    }

    @ViewBuilder
    private var shapeStroke: some View {
        switch token.shape {
        case .circle:
            Circle().stroke(DesignColour.separator, lineWidth: 1)
        case .square:
            RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(DesignColour.separator, lineWidth: 1)
        case .diamond:
            RoundedRectangle(cornerRadius: 4, style: .continuous).stroke(DesignColour.separator, lineWidth: 1).rotationEffect(.degrees(45)).padding(4)
        }
    }
}

struct WallZoneSummaryRow: View {
    let wallZone: WallZone

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.xSmall) {
            HStack(alignment: .firstTextBaseline) {
                Text(wallZone.name)
                    .font(DesignTypography.navigationTitle)
                    .fontWeight(.bold)
                Spacer(minLength: DesignSpacing.small)
                StatusChip(
                    title: L10n.wallAvailability(wallZone.availability),
                    systemImage: wallZone.availability == .active ? "checkmark.circle" : "pause.circle",
                    colour: wallZone.availability == .active ? DesignColour.success : DesignColour.warning
                )
            }
            if !wallZone.locationDescription.isEmpty {
                Text(wallZone.locationDescription)
                    .font(DesignTypography.supporting)
                    .foregroundStyle(DesignColour.textSecondary)
            }
            HStack(spacing: DesignSpacing.compact) {
                Label(L10n.wallKind(wallZone.wallKind), systemImage: wallKindIcon)
                    .font(DesignTypography.caption)
                    .foregroundStyle(DesignColour.textSecondary)
                Label("\(wallZone.routeCount)", systemImage: "circle.hexagongrid")
                Label("\(wallZone.betaCount)", systemImage: "link")
                if let date = wallZone.latestResetDate {
                    Label(date.formatted(.relative(presentation: .named)), systemImage: "arrow.clockwise")
                }
            }
            .font(DesignTypography.caption)
            .foregroundStyle(DesignColour.textSecondary)
        }
        .padding(.vertical, DesignSpacing.small)
        .accessibilityElement(children: .combine)
    }

    private var wallKindIcon: String {
        switch wallZone.wallKind {
        case .regularSetWall: "rectangle.stack"
        case .sprayWall: "square.grid.3x3"
        case .compWall: "flag"
        }
    }
}

struct SkeletonPlaceholder: View {
    var rows = 3

    var body: some View {
        VStack(spacing: DesignSpacing.compact) {
            ForEach(0..<rows, id: \.self) { index in
                HStack(spacing: DesignSpacing.compact) {
                    RoundedRectangle(cornerRadius: DesignRadius.control)
                        .fill(DesignColour.surfaceElevated)
                        .frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: DesignSpacing.small) {
                        Capsule().fill(DesignColour.surfaceElevated).frame(height: 12)
                        Capsule().fill(DesignColour.surfacePrimary).frame(width: index.isMultiple(of: 2) ? 150 : 210, height: 9)
                    }
                }
                .accessibilityHidden(true)
            }
        }
        .padding()
        .redacted(reason: .placeholder)
        .accessibilityLabel(L10n.State.loading)
    }
}
