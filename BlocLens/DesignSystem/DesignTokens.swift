import SwiftUI

enum DesignColour {
    static let brandPrimary = Color(red: 0.02, green: 0.43, blue: 0.98)
    static let brandPrimaryPressed = Color(red: 0.01, green: 0.31, blue: 0.78)
    static let brandTint = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.16, green: 0.51, blue: 1, alpha: 0.18)
            : UIColor(red: 0.02, green: 0.43, blue: 0.98, alpha: 0.10)
    })
    static let backgroundPrimary = Color(uiColor: .systemBackground)
    static let backgroundSecondary = Color(uiColor: .systemGroupedBackground)
    static let surfacePrimary = Color(uiColor: .secondarySystemBackground)
    static let surfaceElevated = Color(uiColor: .tertiarySystemBackground)
    static let textPrimary = Color(uiColor: .label)
    static let textSecondary = Color(uiColor: .secondaryLabel)
    static let textTertiary = Color(uiColor: .tertiaryLabel)
    static let separator = Color(uiColor: .separator)
    static let success = Color(uiColor: .systemGreen)
    static let warning = Color(uiColor: .systemOrange)
    static let error = Color(uiColor: .systemRed)
    static let offline = Color(uiColor: .systemGray)
    static let archived = Color(uiColor: .systemBrown)

    // Compatibility aliases for the established Stage 1–4 presentation code.
    static let opticBlue = brandPrimary
    static let background = backgroundPrimary
    static let groupedBackground = backgroundSecondary
    static let surface = surfacePrimary
    static let elevatedSurface = surfaceElevated
    static let primaryText = textPrimary
    static let secondaryText = textSecondary
    static let tertiaryText = textTertiary
    static let destructive = error
}

enum DesignTypography {
    static let largeScreenTitle: Font = .largeTitle.weight(.bold)
    static let navigationTitle: Font = .title2.weight(.bold)
    static let sectionTitle: Font = .title3.weight(.semibold)
    static let cardTitle: Font = .headline
    static let body: Font = .body
    static let supporting: Font = .subheadline
    static let caption: Font = .caption
    static let gradeEmphasis: Font = .title2.weight(.bold).monospacedDigit()
    static let numericStatistic: Font = .title.weight(.bold).monospacedDigit()
}

enum DesignSpacing {
    static let xSmall: CGFloat = 4
    static let small: CGFloat = 8
    static let compact: CGFloat = 12
    static let medium: CGFloat = 16
    static let comfortable: CGFloat = 20
    static let large: CGFloat = 24
    static let xLarge: CGFloat = 32
}

enum DesignRadius {
    static let control: CGFloat = 10
    static let card: CGFloat = 18
    static let sheetSection: CGFloat = 24
    static let small = control
    static let medium = card
    static let large = sheetSection
}

enum DesignMotion {
    static let quick = Animation.easeOut(duration: 0.16)
    static let stateChange = Animation.spring(response: 0.28, dampingFraction: 0.86)
    static let reveal = Animation.easeInOut(duration: 0.24)

    static func animation(_ animation: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : animation
    }
}

struct PageTitleStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(DesignTypography.largeScreenTitle)
            .foregroundStyle(DesignColour.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CardStyle: ViewModifier {
    var elevated = false

    func body(content: Content) -> some View {
        content
            .padding(DesignSpacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                elevated ? DesignColour.surfaceElevated : DesignColour.surfacePrimary,
                in: RoundedRectangle(cornerRadius: DesignRadius.card, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: DesignRadius.card, style: .continuous)
                    .stroke(DesignColour.separator.opacity(0.42), lineWidth: 0.5)
            }
    }
}

struct AdaptiveGlassStyle: ViewModifier {
    let interactive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(
                .regular.tint(DesignColour.brandTint).interactive(interactive),
                in: RoundedRectangle(cornerRadius: DesignRadius.card, style: .continuous)
            )
        } else {
            content
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DesignRadius.card, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: DesignRadius.card, style: .continuous)
                        .stroke(DesignColour.separator.opacity(0.38), lineWidth: 0.5)
                }
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.horizontal, DesignSpacing.medium)
            .foregroundStyle(.white)
            .background(
                isEnabled
                    ? (configuration.isPressed ? DesignColour.brandPrimaryPressed : DesignColour.brandPrimary)
                    : DesignColour.brandPrimary.opacity(0.32),
                in: RoundedRectangle(cornerRadius: DesignRadius.control, style: .continuous)
            )
            .scaleEffect(configuration.isPressed && isEnabled ? 0.985 : 1)
            .animation(DesignMotion.quick, value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.horizontal, DesignSpacing.medium)
            .foregroundStyle(isEnabled ? DesignColour.brandPrimary : DesignColour.textTertiary)
            .background(
                configuration.isPressed ? DesignColour.brandTint : DesignColour.surfacePrimary,
                in: RoundedRectangle(cornerRadius: DesignRadius.control, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: DesignRadius.control, style: .continuous)
                    .stroke(DesignColour.separator.opacity(isEnabled ? 0.7 : 0.3), lineWidth: 0.5)
            }
    }
}

struct QuietButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .frame(minHeight: 44)
            .padding(.horizontal, DesignSpacing.small)
            .foregroundStyle(isEnabled ? DesignColour.brandPrimary : DesignColour.textTertiary)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

struct CompactActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, DesignSpacing.medium)
            .frame(minHeight: 44)
            .foregroundStyle(isEnabled ? DesignColour.brandPrimary : DesignColour.textTertiary)
            .background(DesignColour.brandTint.opacity(configuration.isPressed ? 0.7 : 1), in: Capsule())
    }
}

struct IconButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .frame(width: 44, height: 44)
            .foregroundStyle(isEnabled ? DesignColour.textPrimary : DesignColour.textTertiary)
            .background(DesignColour.surfaceElevated.opacity(configuration.isPressed ? 0.65 : 0.95), in: Circle())
            .overlay { Circle().stroke(DesignColour.separator.opacity(0.45), lineWidth: 0.5) }
    }
}

extension View {
    func pageTitleStyle() -> some View { modifier(PageTitleStyle()) }
    func cardStyle(elevated: Bool = false) -> some View { modifier(CardStyle(elevated: elevated)) }
    func adaptiveGlass(interactive: Bool = false) -> some View { modifier(AdaptiveGlassStyle(interactive: interactive)) }
    func blocGlass(interactive: Bool = false) -> some View { modifier(BlocGlassModifier(interactive: interactive)) }
    func font(_ token: BlocFontToken) -> some View { font(token.font) }
}

// MARK: - Bloc Tokens — Cold Zinc A (Phase 1)

/// Optic Blue single accent + 12 hold colours with shape + lifecycle semantics.
enum BlocColor {
    static let opticBlue = Color(red: 0.04, green: 0.40, blue: 1.0)
    static let opticBlueTint = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.04, green: 0.40, blue: 1.0, alpha: 0.18)
            : UIColor(red: 0.04, green: 0.40, blue: 1.0, alpha: 0.10)
    })

    // Lifecycle semantics — time-sensitive route state.
    static let fresh = opticBlue
    static let project = Color(red: 0.85, green: 0.56, blue: 0.04)
    static let resetSoon = Color(red: 0.86, green: 0.15, blue: 0.15)
    static let archived = Color(red: 0.39, green: 0.45, blue: 0.55)
    static let statusLifecycle: [String: Color] = [
        "fresh": fresh,
        "active": fresh,
        "project": project,
        "resetSoon": resetSoon,
        "archived": archived,
    ]

    enum HoldShape: String {
        case circle, square, diamond
    }

    struct HoldColor: Identifiable, Equatable {
        let name: String
        let color: Color
        let textColor: Color
        let shape: HoldShape
        var id: String { name }
        static func == (lhs: HoldColor, rhs: HoldColor) -> Bool { lhs.name == rhs.name }
    }

    // Copy for VisualComponents fallback — keep as Color accessor.
    static let grey = HoldColor(name: "Grey", color: Color(uiColor: .systemGray), textColor: .white, shape: .diamond)

    static let routePalette: [HoldColor] = [
        HoldColor(name: "Black", color: Color(uiColor: .label), textColor: .white, shape: .circle),
        HoldColor(name: "White", color: Color(uiColor: .systemBackground), textColor: .black, shape: .circle),
        HoldColor(name: "Yellow", color: .yellow, textColor: .black, shape: .square),
        HoldColor(name: "Red", color: .red, textColor: .white, shape: .diamond),
        HoldColor(name: "Blue", color: .blue, textColor: .white, shape: .circle),
        HoldColor(name: "Green", color: .green, textColor: .white, shape: .square),
        HoldColor(name: "Purple", color: .purple, textColor: .white, shape: .diamond),
        HoldColor(name: "Orange", color: .orange, textColor: .black, shape: .circle),
        HoldColor(name: "Pink", color: .pink, textColor: .black, shape: .square),
        HoldColor(name: "Grey", color: Color(uiColor: .systemGray), textColor: .white, shape: .diamond),
        HoldColor(name: "Mint", color: Color(red: 0.60, green: 0.90, blue: 0.80), textColor: .black, shape: .circle),
        HoldColor(name: "Wood", color: Color(red: 0.55, green: 0.27, blue: 0.07), textColor: .white, shape: .square),
    ]
}

struct BlocFontToken: CustomStringConvertible {
    let font: Font
    var description: String { "tabular \(String(describing: font))" }
}

enum BlocTypography {
    static let grade = BlocFontToken(font: .system(size: 22, weight: .bold).monospacedDigit())
    static let status: Font = .system(size: 11, weight: .semibold)
    static let metadata: Font = .system(size: 11, weight: .regular)
    static let hero: Font = .system(size: 34, weight: .bold)
    static let caption: Font = .caption
}

enum BlocSpacing {
    static let sectionGap: CGFloat = 40
    static let xSmall: CGFloat = 4
    static let small: CGFloat = 8
    static let compact: CGFloat = 12
    static let medium: CGFloat = 16
    static let comfortable: CGFloat = 20
    static let large: CGFloat = 24
    static let xLarge: CGFloat = 32
    static let xxLarge: CGFloat = 48
}

enum BlocRadius {
    static let control: CGFloat = 10
    static let card: CGFloat = 16
    static let container: CGFloat = 20
    static let sheet: CGFloat = 24
    static let capsule: CGFloat = 999
}

enum BlocMaterial {
    static let glass: Material = .ultraThin
}

struct BlocGlassModifier: ViewModifier {
    let interactive: Bool
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.tint(BlocColor.opticBlueTint).interactive(interactive), in: RoundedRectangle(cornerRadius: BlocRadius.card, style: .continuous))
        } else {
            content.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: BlocRadius.card, style: .continuous))
        }
    }
}

enum BlocHaptics {
    static let selection = "selection"
    static func selectionChanged() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    static func lightImpact() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
