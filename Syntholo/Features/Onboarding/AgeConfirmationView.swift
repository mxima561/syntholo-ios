import SwiftUI

struct AgeConfirmationView: View {
    let selectedAgeBand: AgeBand?
    let onSelectAgeBand: (AgeBand) -> Void
    let onUnderThirteen: () -> Void

    var body: some View {
        OnboardingPage(
            eyebrow: "Orientation · 2/6",
            progress: 2,
            title: "Which age range are you in?",
            introduction: "Syntholo is for learners age 13 and older.",
            accessibilityIdentifier: "onboarding.age"
        ) {
            ChoiceListView(
                items: [
                    ChoiceListItem(
                        id: AgeBand.teen,
                        title: "I’m 13–17",
                        detail: "Continue with the learner experience.",
                        systemImage: "person"
                    ),
                    ChoiceListItem(
                        id: AgeBand.adult,
                        title: "I’m 18 or older",
                        detail: "Continue with the learner experience.",
                        systemImage: "person"
                    )
                ],
                selectedID: selectedAgeBand,
                onSelect: onSelectAgeBand
            )

            Button("I’m under 13", action: onUnderThirteen)
                .font(.body.weight(.semibold))
                .foregroundStyle(OnboardingPalette.academicInk)
                .frame(maxWidth: .infinity, minHeight: 44)

            Text("Your age range is used only to confirm eligibility.")
                .font(.footnote)
                .foregroundStyle(OnboardingPalette.academicInk.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct AgeRestrictedView: View {
    var body: some View {
        OnboardingPage(
            eyebrow: "Age requirement",
            progress: 2,
            title: "Close Syntholo",
            introduction: "Syntholo is available to learners age 13 and older. No information was saved.",
            accessibilityIdentifier: "onboarding.age-restricted"
        ) {
            HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                Image(systemName: "hand.raised")
                    .foregroundStyle(OnboardingPalette.correctionCoral)
                    .accessibilityHidden(true)
                Text("You can return when you’re 13.")
                    .foregroundStyle(OnboardingPalette.academicInk)
            }
            .font(.body.weight(.semibold))
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}
