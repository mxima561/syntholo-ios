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
                        detail: "Warm and positive.",
                        systemImage: "heart"
                    ),
                    ChoiceListItem(
                        id: CoachMode.funny,
                        title: "Funny",
                        detail: "Playful, with light humor.",
                        systemImage: "face.smiling"
                    ),
                    ChoiceListItem(
                        id: CoachMode.strict,
                        title: "Strict",
                        detail: "Direct and no-nonsense.",
                        systemImage: "checkmark.seal"
                    ),
                    ChoiceListItem(
                        id: CoachMode.chill,
                        title: "Chill",
                        detail: "Calm and low-pressure.",
                        systemImage: "waveform"
                    ),
                    ChoiceListItem(
                        id: CoachMode.socratic,
                        title: "Socratic",
                        detail: "Curious and reflective.",
                        systemImage: "questionmark.bubble"
                    )
                ],
                selectedID: selectedMode,
                onSelect: onSelectMode
            )
        }
    }
}
