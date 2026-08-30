import SwiftUI

struct OnboardingRootView: View {
    @Bindable var store: OnboardingStore
    let coordinator: OnboardingCoordinator

    @State private var isEmailAuthPresented = false

    init(coordinator: OnboardingCoordinator) {
        self.coordinator = coordinator
        store = coordinator.onboardingStore
    }

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
        .sheet(isPresented: $isEmailAuthPresented) {
            EmailAuthView(
                authClient: coordinator.authClient,
                onAuthenticated: { user in
                    isEmailAuthPresented = false
                    finishAuthentication(user, provider: .password)
                }
            )
        }
    }

    @ViewBuilder
    private var currentStep: some View {
        if let profileRecoveryKind = coordinator.profileRecoveryKind {
            recoveryView(for: profileRecoveryKind)
        } else {
            switch store.step {
            case .welcome:
                WelcomeView(
                    isStartEnabled: store.canAdvance,
                    onStart: coordinator.startOnboarding
                )
            case .age:
                AgeConfirmationView(
                    selectedAgeBand: store.draft.ageBand,
                    onSelectAgeBand: coordinator.confirmAge,
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
                    onSelectPath: coordinator.selectPath
                )
            case .coach:
                CoachModeView(
                    selectedMode: store.draft.coachMode,
                    onSelectMode: coordinator.selectCoachMode
                )
            case .account:
                AccountCreationView(
                    authClient: coordinator.authClient,
                    onAuthenticated: finishAuthentication,
                    onContinueWithEmail: {
                        isEmailAuthPresented = true
                    }
                )
            case .savingProfile:
                savingProfileView
            case .firstLessonHandoff:
                FirstLessonHandoffView(
                    onStartFirstLesson: coordinator.completeFirstLessonHandoff
                )
            }
        }
    }

    @ViewBuilder
    private func recoveryView(
        for kind: ProfileRecoveryKind
    ) -> some View {
        switch kind {
        case .checkingProfile:
            checkingProfileView
        case .profileCheckFailed:
            ProfileCheckRetryView {
                Task { @MainActor in
                    await coordinator.retryProfileRecovery()
                }
            }
        case .savingProfile:
            savingProfileView
        case .profileSaveFailed:
            ProfileSaveRetryView {
                Task { @MainActor in
                    await coordinator.retryProfileRecovery()
                }
            }
        }
    }

    private var goalView: some View {
        OnboardingPage(
            eyebrow: "ORIENTATION · 3/6",
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
                        systemImage: "book.pages",
                        accessibilityIdentifier: "Study smarter"
                    ),
                    ChoiceListItem(
                        id: LearnerGoal.workProductivity,
                        title: "Improve my workflow",
                        detail: "Draft, summarize, and build repeatable work steps.",
                        systemImage: "checklist",
                        accessibilityIdentifier: "Improve my workflow"
                    ),
                    ChoiceListItem(
                        id: LearnerGoal.createContent,
                        title: "Create with AI",
                        detail: "Plan and revise writing, images, and media.",
                        systemImage: "pencil.and.outline",
                        accessibilityIdentifier: "Create with AI"
                    ),
                    ChoiceListItem(
                        id: LearnerGoal.buildWithAI,
                        title: "Build with AI",
                        detail: "Turn an idea into a working tool or prototype.",
                        systemImage: "hammer",
                        accessibilityIdentifier: "Build with AI"
                    )
                ],
                selectedID: store.draft.goal,
                onSelect: coordinator.selectGoal
            )
        }
    }

    private var experienceView: some View {
        OnboardingPage(
            eyebrow: "ORIENTATION · 4/6",
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
                        systemImage: "figure.walk",
                        accessibilityIdentifier: "Beginner-friendly"
                    ),
                    ChoiceListItem(
                        id: ExperienceLevel.intermediate,
                        title: "Some experience",
                        detail: "Practice stronger prompts and multi-step workflows.",
                        systemImage: "arrow.triangle.2.circlepath",
                        accessibilityIdentifier: "Some experience"
                    ),
                    ChoiceListItem(
                        id: ExperienceLevel.advanced,
                        title: "Regular practice",
                        detail: "Focus on evaluation, automation, and building.",
                        systemImage: "wrench.and.screwdriver",
                        accessibilityIdentifier: "Regular practice"
                    )
                ],
                selectedID: store.draft.experience,
                onSelect: coordinator.selectExperience
            )
        }
    }

    private var checkingProfileView: some View {
        OnboardingPage(
            eyebrow: "PROFILE CHECK",
            progress: 6,
            title: "Checking your profile",
            introduction: "Making sure your saved profile is ready.",
            accessibilityIdentifier: "onboarding.profile-checking"
        ) {
            ProgressView()
                .controlSize(.large)
                .tint(OnboardingPalette.lectureBlue)
                .accessibilityLabel("Checking profile")
        }
    }

    private var savingProfileView: some View {
        OnboardingPage(
            eyebrow: "ORIENTATION · 6/6",
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

    private func finishAuthentication(
        _ user: AuthenticatedUser,
        provider: AuthenticationProvider
    ) {
        Task { @MainActor in
            await coordinator.authenticated(user, provider: provider)
        }
    }
}

private struct ProfileSaveRetryView: View {
    let onRetry: () -> Void

    var body: some View {
        OnboardingPage(
            eyebrow: "ACCOUNT SAVED",
            progress: 6,
            title: "Finish saving your route",
            introduction: "Your account is ready, but your learning route didn’t save.",
            accessibilityIdentifier: "onboarding.profile-retry"
        ) {
            Label(
                "Your choices are safe on this device.",
                systemImage: "arrow.clockwise.circle"
            )
            .font(.body)
            .foregroundStyle(OnboardingPalette.academicInk)
            .fixedSize(horizontal: false, vertical: true)

            PrimaryButton(
                title: "Retry saving profile",
                action: onRetry
            )
            .accessibilityIdentifier("onboarding.profile-retry-button")
        }
    }
}

private struct ProfileCheckRetryView: View {
    let onRetry: () -> Void

    var body: some View {
        OnboardingPage(
            eyebrow: "PROFILE CHECK",
            progress: 6,
            title: "We couldn’t check your profile",
            introduction: "Your account is signed in. Check again before we save your learning route.",
            accessibilityIdentifier: "onboarding.profile-check-retry"
        ) {
            Label(
                "Your choices are safe on this device.",
                systemImage: "arrow.clockwise.circle"
            )
            .font(.body)
            .foregroundStyle(OnboardingPalette.academicInk)
            .fixedSize(horizontal: false, vertical: true)

            PrimaryButton(
                title: "Retry checking profile",
                action: onRetry
            )
            .accessibilityIdentifier("onboarding.profile-check-retry-button")
        }
    }
}
