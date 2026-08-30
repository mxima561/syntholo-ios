import SwiftUI

struct CoachModeView: View {
    let selectedMode: CoachMode
    let onSelectMode: (CoachMode) -> Void

    var body: some View {
        OnboardingPage(
            eyebrow: "ORIENTATION · 5/6",
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
                        systemImage: "heart",
                        accessibilityIdentifier: "Supportive"
                    ),
                    ChoiceListItem(
                        id: CoachMode.funny,
                        title: "Funny",
                        detail: "Playful, with light humor.",
                        systemImage: "face.smiling",
                        accessibilityIdentifier: "Funny"
                    ),
                    ChoiceListItem(
                        id: CoachMode.strict,
                        title: "Strict",
                        detail: "Direct and no-nonsense.",
                        systemImage: "checkmark.seal",
                        accessibilityIdentifier: "Strict"
                    ),
                    ChoiceListItem(
                        id: CoachMode.chill,
                        title: "Chill",
                        detail: "Calm and low-pressure.",
                        systemImage: "waveform",
                        accessibilityIdentifier: "Chill"
                    ),
                    ChoiceListItem(
                        id: CoachMode.socratic,
                        title: "Socratic",
                        detail: "Curious and reflective.",
                        systemImage: "questionmark.bubble",
                        accessibilityIdentifier: "Socratic"
                    )
                ],
                selectedID: selectedMode,
                onSelect: onSelectMode
            )
        }
    }
}
