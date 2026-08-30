import SwiftUI

struct FirstLessonHandoffView: View {
    let onStartFirstLesson: () -> Void

    var body: some View {
        OnboardingPage(
            eyebrow: "Route ready",
            progress: 6,
            title: "Foundations starts with better prompts",
            introduction: "Your first lesson practices a clear request, useful context, and a check for weak output.",
            accessibilityIdentifier: "onboarding.first-lesson"
        ) {
            Label("Foundations · Lesson 1", systemImage: "book.pages")
                .font(.body.weight(.semibold))
                .foregroundStyle(OnboardingPalette.proofGreen)

            PrimaryButton(
                title: "Start the first lesson",
                action: onStartFirstLesson
            )
            .accessibilityIdentifier("onboarding.start-first-lesson")
        }
    }
}
