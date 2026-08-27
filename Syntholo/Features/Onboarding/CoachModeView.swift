import SwiftUI

struct CoachModeView: View {
    let selectedMode: CoachMode
    let onSelectMode: (CoachMode) -> Void

    var body: some View {
        OnboardingPage(
            eyebrow: "Orientation · 5/6",
            progress: 5,
            title: "How should your coach sound?",
            introduction: "This changes the tone of feedback, not what gets checked.",
            accessibilityIdentifier: "onboarding.coach"
        ) {
            ChoiceListView(
                items: [
                    ChoiceListItem(
                        id: CoachMode.supportive,
                        title: "Supportive",
                        detail: "Explains the next step and points out progress.",
                        systemImage: "heart"
                    ),
                    ChoiceListItem(
                        id: CoachMode.funny,
                        title: "Funny",
                        detail: "Uses light humor while keeping feedback clear.",
                        systemImage: "face.smiling"
                    ),
                    ChoiceListItem(
                        id: CoachMode.strict,
                        title: "Strict",
                        detail: "Names mistakes directly and asks you to revise.",
                        systemImage: "checkmark.seal"
                    ),
                    ChoiceListItem(
                        id: CoachMode.chill,
                        title: "Chill",
                        detail: "Keeps feedback brief and low-pressure.",
                        systemImage: "waveform"
                    ),
                    ChoiceListItem(
                        id: CoachMode.socratic,
                        title: "Socratic",
                        detail: "Uses questions to help you test your reasoning.",
                        systemImage: "questionmark.bubble"
                    )
                ],
                selectedID: selectedMode,
                onSelect: onSelectMode
            )
        }
    }
}
