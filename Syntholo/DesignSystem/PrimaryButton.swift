import SwiftUI

struct PrimaryButtonConfiguration: Equatable, Sendable {
    let minimumHeight: CGFloat
    static let `default` = PrimaryButtonConfiguration(minimumHeight: 48)
}

struct PrimaryButton: View {
    let title: LocalizedStringResource
    let action: () -> Void
    var isEnabled = true
    var configuration = PrimaryButtonConfiguration.default

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(SyntholoTextStyle.label)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .frame(minHeight: configuration.minimumHeight)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: Radius.control))
        .disabled(!isEnabled)
        .accessibilityAddTraits(.isButton)
    }
}
