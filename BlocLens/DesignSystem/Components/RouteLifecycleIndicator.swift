import SwiftUI

/// Lifecycle phase for route status — design-level (Fresh/Active/ResetSoon/Archived).
/// Maps `ClimbingRoute.lifecycle` + dates to the 4-step glanceable indicator.
/// Rule: only create when colour+icon+caption are reused; this consolidates the
/// archived duplication previously in `RouteDetailView` + `WallZoneRouteListView`.
struct RouteLifecycleIndicator: View {
    enum Lifecycle: String, CaseIterable {
        case fresh
        case active
        case resetSoon
        case archived
    }

    let lifecycle: Lifecycle
    var showsCaption: Bool = true

    /// Convenience from domain model — fresh = set <7d ago, resetSoon = archives <7d, else active/archived.
    init(route: ClimbingRoute, showsCaption: Bool = true) {
        self.showsCaption = showsCaption
        if route.lifecycle == .archived {
            lifecycle = .archived
        } else if let archive = route.expectedArchiveDate, archive.timeIntervalSinceNow < 7 * 24 * 3600 {
            lifecycle = .resetSoon
        } else if let reset = route.resetDate, Date().timeIntervalSince(reset) < 7 * 24 * 3600 {
            lifecycle = .fresh
        } else {
            lifecycle = .active
        }
    }

    init(lifecycle: Lifecycle, showsCaption: Bool = true) {
        self.lifecycle = lifecycle
        self.showsCaption = showsCaption
    }

    var body: some View {
        Label {
            if showsCaption { Text(caption) }
        } icon: {
            Image(systemName: icon)
        }
        .font(BlocTypography.status)
        .padding(.horizontal, BlocSpacing.compact)
        .frame(minHeight: 28)
        .foregroundStyle(colour)
        .background(colour.opacity(0.12), in: Capsule())
        .overlay { Capsule().stroke(colour.opacity(0.25), lineWidth: 0.5) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(caption)
    }

    private var colour: Color {
        switch lifecycle {
        case .fresh, .active: BlocColor.fresh
        case .resetSoon: BlocColor.resetSoon
        case .archived: BlocColor.archived
        }
    }

    private var icon: String {
        switch lifecycle {
        case .fresh: "sparkles"
        case .active: "checkmark.circle"
        case .resetSoon: "clock.badge.exclamationmark"
        case .archived: "archivebox"
        }
    }

    private var caption: LocalizedStringResource {
        switch lifecycle {
        case .fresh: "routeLifecycle.fresh"
        case .active: "routeLifecycle.active"
        case .resetSoon: "routeLifecycle.resetSoon"
        case .archived: L10n.Route.archived
        }
    }
}

#Preview("Lifecycle — Light") {
    HStack(spacing: BlocSpacing.small) {
        RouteLifecycleIndicator(lifecycle: .fresh)
        RouteLifecycleIndicator(lifecycle: .active)
        RouteLifecycleIndicator(lifecycle: .resetSoon)
        RouteLifecycleIndicator(lifecycle: .archived)
    }
    .padding()
    .preferredColorScheme(.light)
}

#Preview("Lifecycle — Dark") {
    HStack(spacing: BlocSpacing.small) {
        RouteLifecycleIndicator(lifecycle: .fresh)
        RouteLifecycleIndicator(lifecycle: .active)
        RouteLifecycleIndicator(lifecycle: .resetSoon)
        RouteLifecycleIndicator(lifecycle: .archived)
    }
    .padding()
    .preferredColorScheme(.dark)
}
