import SwiftUI

enum DesignColour {
    static let opticBlue = Color(red: 0.02, green: 0.43, blue: 0.98)
    static let background = Color(uiColor: .systemBackground)
    static let surface = Color(uiColor: .secondarySystemBackground)
    static let primaryText = Color(uiColor: .label)
    static let secondaryText = Color(uiColor: .secondaryLabel)
    static let success = Color(uiColor: .systemGreen)
    static let warning = Color(uiColor: .systemOrange)
    static let destructive = Color(uiColor: .systemRed)
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
    }
}

extension View {
    func pageTitleStyle() -> some View { modifier(PageTitleStyle()) }
    func cardStyle() -> some View { modifier(CardStyle()) }
}
