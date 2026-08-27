import SwiftUI

struct AccountCreationView: View {
    let onContinueWithApple: () -> Void
    let onContinueWithGoogle: () -> Void
    let onContinueWithEmail: () -> Void

    var body: some View {
        OnboardingPage(
            eyebrow: "Orientation · 6/6",
            progress: 6,
            title: "Save your learning route",
            introduction: "Create an account to keep your route and lesson progress.",
            accessibilityIdentifier: "onboarding.account"
        ) {
            VStack(spacing: Space.sm) {
                providerButton(
                    title: "Continue with Apple",
                    systemImage: "apple.logo",
                    action: onContinueWithApple
                )
                providerButton(
                    title: "Continue with Google",
                    systemImage: nil,
                    action: onContinueWithGoogle
                )
                providerButton(
                    title: "Continue with email",
                    systemImage: "envelope",
                    action: onContinueWithEmail
                )
            }

            Text("Your account stores your learning choices and progress.")
                .font(.footnote)
                .foregroundStyle(OnboardingPalette.academicInk.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func providerButton(
        title: LocalizedStringKey,
        systemImage: String?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Space.sm) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .frame(width: 24)
                        .accessibilityHidden(true)
                } else {
                    Color.clear
                        .frame(width: 24, height: 1)
                        .accessibilityHidden(true)
                }

                Text(title)
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)

                Color.clear
                    .frame(width: 24, height: 1)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(OnboardingPalette.academicInk)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: Layout.minimumControlHeight)
            .background(OnboardingPalette.campusPaper)
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(OnboardingPalette.academicInk.opacity(0.42), lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
    }
}
