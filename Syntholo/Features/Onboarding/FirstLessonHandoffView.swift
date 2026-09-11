import SwiftUI

struct FirstLessonHandoffView: View {
    let presentationState: FirstLessonHandoffPresentationState
    let onPreviewFirstLesson: () -> Void

    var body: some View {
        OnboardingPage(
            eyebrow: "ROUTE READY",
            progress: 6,
            title: "Preview your first lesson",
            introduction: "We’ll resolve the exact read-only Foundations lesson version before opening Learn.",
            accessibilityIdentifier: "onboarding.first-lesson"
        ) {
            Label("Read-only lesson preview", systemImage: "book.pages")
                .font(.body.weight(.semibold))
                .foregroundStyle(OnboardingPalette.proofGreen)
                .fixedSize(horizontal: false, vertical: true)

            resolutionStatus

            PrimaryButton(
                title: actionTitle,
                action: onPreviewFirstLesson,
                isEnabled: presentationState != .loading
            )
            .accessibilityIdentifier("onboarding.preview-first-lesson")
        }
    }

    @ViewBuilder
    private var resolutionStatus: some View {
        switch presentationState {
        case .idle:
            EmptyView()
        case .loading:
            ProgressView("Preparing lesson preview…")
                .font(.body)
                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                .accessibilityIdentifier(
                    "onboarding.preview-first-lesson.loading"
                )
        case .retry:
            Label(
                "We couldn’t open the lesson preview. Your place is safe.",
                systemImage: "arrow.clockwise.circle"
            )
            .font(.body)
            .foregroundStyle(OnboardingPalette.academicInk)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(
                "onboarding.preview-first-lesson.retry"
            )
        }
    }

    private var actionTitle: LocalizedStringResource {
        switch presentationState {
        case .idle, .loading:
            "Preview the first lesson"
        case .retry:
            "Try preview again"
        }
    }
}
