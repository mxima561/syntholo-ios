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
    static let secondaryInk = Color(uiColor: .label)
    static let canvas = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    static let accent = Color.accentColor
    static let success = Color(uiColor: .systemGreen)
    static let warning = Color(uiColor: .systemOrange)

    /// Destructive actions. `systemRed` on a grouped-list background lands near
    /// 3.9:1, which the contrast audit reports as "nearly passed", so this
    /// darkens it in light mode and lightens it in dark mode instead.
    static let destructive = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 1.0, green: 0.62, blue: 0.60, alpha: 1)
                : UIColor(
                    red: 160.0 / 255.0,
                    green: 40.0 / 255.0,
                    blue: 40.0 / 255.0,
                    alpha: 1
                )
        }
    )
}
