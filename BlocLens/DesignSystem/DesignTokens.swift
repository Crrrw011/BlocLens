import SwiftUI

enum DesignColour {
    static let opticBlue = Color(red: 0.02, green: 0.43, blue: 0.98)
    static let background = Color(uiColor: .systemBackground)
    static let groupedBackground = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemBackground)
    static let elevatedSurface = Color(uiColor: .tertiarySystemBackground)
    static let primaryText = Color(uiColor: .label)
    static let secondaryText = Color(uiColor: .secondaryLabel)
    static let tertiaryText = Color(uiColor: .tertiaryLabel)
    static let success = Color(uiColor: .systemGreen)
    static let warning = Color(uiColor: .systemOrange)
    static let destructive = Color(uiColor: .systemRed)
    static let offline = Color(uiColor: .systemGray)
}

enum DesignSpacing {
    static let xSmall: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
    static let xLarge: CGFloat = 32
}

enum DesignRadius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 14
    static let large: CGFloat = 20
}

struct PageTitleStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.largeTitle.bold())
            .foregroundStyle(DesignColour.primaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(DesignSpacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DesignRadius.medium))
            .overlay {
                RoundedRectangle(cornerRadius: DesignRadius.medium)
                    .stroke(DesignColour.secondaryText.opacity(0.12), lineWidth: 1)
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
            .background(DesignColour.opticBlue.opacity(isEnabled ? (configuration.isPressed ? 0.76 : 1) : 0.35))
            .clipShape(RoundedRectangle(cornerRadius: DesignRadius.medium))
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.horizontal, DesignSpacing.medium)
            .foregroundStyle(isEnabled ? DesignColour.opticBlue : DesignColour.tertiaryText)
            .background(DesignColour.surface.opacity(configuration.isPressed ? 0.65 : 1))
            .clipShape(RoundedRectangle(cornerRadius: DesignRadius.medium))
            .overlay {
                RoundedRectangle(cornerRadius: DesignRadius.medium)
                    .stroke(DesignColour.opticBlue.opacity(isEnabled ? 0.35 : 0.12))
            }
    }
}

struct CompactActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, DesignSpacing.medium)
            .frame(minHeight: 44)
            .foregroundStyle(isEnabled ? DesignColour.opticBlue : DesignColour.tertiaryText)
            .background(DesignColour.opticBlue.opacity(configuration.isPressed ? 0.16 : 0.08), in: Capsule())
    }
}

extension View {
    func pageTitleStyle() -> some View { modifier(PageTitleStyle()) }
    func cardStyle() -> some View { modifier(CardStyle()) }
}
