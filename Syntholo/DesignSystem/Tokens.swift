import SwiftUI

enum Space {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}

enum Radius {
    static let control: CGFloat = 14
    static let card: CGFloat = 20
}

enum Layout {
    static let minimumControlHeight: CGFloat = 48
    static let pageInset: CGFloat = 20
}

enum SyntholoColor {
    static let ink = Color.primary
    static let secondaryInk = Color.secondary
    static let canvas = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    static let accent = Color.accentColor
    static let success = Color(uiColor: .systemGreen)
    static let warning = Color(uiColor: .systemOrange)
}
