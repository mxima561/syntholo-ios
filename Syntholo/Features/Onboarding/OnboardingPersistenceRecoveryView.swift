import Accessibility
import SwiftUI

struct OnboardingPersistenceRecoveryView: View {
    let failure: OnboardingPersistenceFailure
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(alignment: .top, spacing: Space.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(OnboardingPalette.correctionCoral)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(OnboardingPalette.academicInk)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(OnboardingPalette.academicInk.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button("Try again", action: onRetry)
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(minHeight: Layout.minimumControlHeight)
                .accessibilityIdentifier("onboarding.persistence.retry")
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.sm)
        .background(OnboardingPalette.campusPaper)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(OnboardingPalette.correctionCoral.opacity(0.45))
                .frame(height: 1)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding.persistence.failure")
        .task(id: failure) {
            AccessibilityNotification.Announcement(
                "\(String(localized: title)). \(String(localized: message))"
            ).post()
        }
    }

    private var title: LocalizedStringResource {
        switch failure {
        case .load:
            "We couldn’t check saved choices"
        case .save:
            "These choices aren’t saved yet"
        case .clear:
            "Saved setup data wasn’t removed"
        }
    }

    private var message: LocalizedStringResource {
        switch failure {
        case .load:
            "Try again to recover any setup choices already stored on this device."
        case .save:
            "Your selection is still here. Try again to keep it after you close the app."
        case .clear:
            "Your current setup is safe. Try again to remove the old draft from this device."
        }
    }
}
