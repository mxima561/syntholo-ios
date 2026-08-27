import SwiftUI

struct OnboardingRootView: View {
    @Bindable var store: OnboardingStore
    let authClient: any AuthClient
    let onAuthenticated: @MainActor (AuthenticatedUser) -> Void
    let onContinueWithEmail: () -> Void
    let onStartFirstLesson: () -> Void

    var body: some View {
        NavigationStack {
            currentStep
                .toolbar {
                    if store.canGoBack {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Back", systemImage: "chevron.left") {
                                store.goBack()
                            }
                            .labelStyle(.titleAndIcon)
                            .frame(minHeight: 44)
                            .accessibilityIdentifier("onboarding.back")
                        }
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
        }
        .tint(OnboardingPalette.lectureBlue)
        .preferredColorScheme(.light)
        .task {
            await store.restore()
        }
    }

    @ViewBuilder
    private var currentStep: some View {
        switch store.step {
        case .welcome:
            WelcomeView(onStart: store.advance)
        case .age:
            AgeConfirmationView(
                selectedAgeBand: store.draft.ageBand,
                onSelectAgeBand: store.selectAgeBand,
                onUnderThirteen: store.rejectUnderThirteen
            )
        case .ageRestricted:
            AgeRestrictedView()
        case .goal:
            goalView
        case .experience:
            experienceView
        case .pathRecommendation:
            PathRecommendationView(
                recommendedPath: store.recommendedPath ?? .school,
                selectedPath: store.draft.path,
                onSelectPath: store.selectPath
            )
        case .coach:
            CoachModeView(
                selectedMode: store.draft.coachMode,
                onSelectMode: store.selectCoachMode
            )
        case .account:
            AccountCreationView(
                authClient: authClient,
                onAuthenticated: onAuthenticated,
                onContinueWithEmail: onContinueWithEmail
            )
        case .savingProfile:
            savingProfileView
        case .firstLessonHandoff:
            FirstLessonHandoffView(onStartFirstLesson: onStartFirstLesson)
        }
    }

    private var goalView: some View {
        OnboardingPage(
            eyebrow: "Orientation · 3/6",
            progress: 3,
            title: "What do you want to use AI for?",
            introduction: "Choose the work you want to practice first.",
            accessibilityIdentifier: "onboarding.goal"
        ) {
            ChoiceListView(
                items: [
                    ChoiceListItem(
                        id: LearnerGoal.studySmarter,
                        title: "Study smarter",
                        detail: "Research, organize notes, and check AI outputs.",
                        systemImage: "book.pages"
                    ),
                    ChoiceListItem(
                        id: LearnerGoal.workProductivity,
                        title: "Improve my workflow",
                        detail: "Draft, summarize, and build repeatable work steps.",
                        systemImage: "checklist"
                    ),
                    ChoiceListItem(
                        id: LearnerGoal.createContent,
                        title: "Create with AI",
                        detail: "Plan and revise writing, images, and media.",
                        systemImage: "pencil.and.outline"
                    ),
                    ChoiceListItem(
                        id: LearnerGoal.buildWithAI,
                        title: "Build with AI",
                        detail: "Turn an idea into a working tool or prototype.",
                        systemImage: "hammer"
                    )
                ],
                selectedID: store.draft.goal,
                onSelect: store.selectGoal
            )
        }
    }

    private var experienceView: some View {
        OnboardingPage(
            eyebrow: "Orientation · 4/6",
            progress: 4,
            title: "How much AI practice have you had?",
            introduction: "This sets the starting pace for Foundations.",
            accessibilityIdentifier: "onboarding.experience"
        ) {
            ChoiceListView(
                items: [
                    ChoiceListItem(
                        id: ExperienceLevel.beginner,
                        title: "Beginner-friendly",
                        detail: "Start with prompting, checking, and responsible use.",
                        systemImage: "figure.walk"
                    ),
                    ChoiceListItem(
                        id: ExperienceLevel.intermediate,
                        title: "Some experience",
                        detail: "Practice stronger prompts and multi-step workflows.",
                        systemImage: "arrow.triangle.2.circlepath"
                    ),
                    ChoiceListItem(
                        id: ExperienceLevel.advanced,
                        title: "Regular practice",
                        detail: "Focus on evaluation, automation, and building.",
                        systemImage: "wrench.and.screwdriver"
                    )
                ],
                selectedID: store.draft.experience,
                onSelect: store.selectExperience
            )
        }
    }

    private var savingProfileView: some View {
        OnboardingPage(
            eyebrow: "Orientation · 6/6",
            progress: 6,
            title: "Saving your route",
            introduction: nil,
            accessibilityIdentifier: "onboarding.saving-profile"
        ) {
            ProgressView("Saving your profile…")
                .font(.body)
                .frame(maxWidth: .infinity, minHeight: 88)
                .accessibilityIdentifier("onboarding.profile-saving")
        }
    }
}
