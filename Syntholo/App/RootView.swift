import SwiftUI

struct RootView: View {
    private let dependencies: AppDependencies
    @Bindable var router: AppRouter

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        router = dependencies.router
    }

    var body: some View {
        Group {
            switch dependencies.onboardingCoordinator.session.state {
            case .loading:
                loadingView
            case .signedOut,
                    .onboarding,
                    .accountPendingProfile,
                    .firstLessonHandoff:
                OnboardingRootView(
                    coordinator: dependencies.onboardingCoordinator,
                    firstLessonHandoffPresentationState:
                        dependencies.firstLessonHandoffCoordinator
                            .presentationState,
                    onPreviewFirstLesson: {
                        dependencies.firstLessonHandoffCoordinator
                            .previewFirstLesson()
                    }
                )
            case .signedIn:
                applicationShell
            case .configurationRequired:
                configurationRequiredView
            }
        }
        .tint(SyntholoColor.accent)
        .safeAreaInset(edge: .bottom) {
            if let persistenceFailure = dependencies.onboardingCoordinator
                .onboardingStore.persistenceFailure {
                OnboardingPersistenceRecoveryView(
                    failure: persistenceFailure,
                    onRetry: {
                        Task { @MainActor in
                            await dependencies.onboardingCoordinator
                                .retryOnboardingPersistence()
                        }
                    }
                )
            }
        }
        .onChange(
            of: dependencies.curriculumStore.state,
            initial: true
        ) {
            dependencies.firstLessonHandoffCoordinator
                .curriculumStoreDidChange()
        }
        .onChange(
            of: dependencies.curriculumStore.isLoadActive,
            initial: true
        ) {
            dependencies.firstLessonHandoffCoordinator
                .curriculumStoreDidChange()
        }
        .task {
            await dependencies.restore()
        }
    }

    private var loadingView: some View {
        ProgressView("Loading Syntholo…")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(SyntholoColor.canvas)
            .accessibilityIdentifier("session.loading")
    }

    private var configurationRequiredView: some View {
        ContentUnavailableView(
            "firebase_setup_required_title",
            systemImage: "wrench.and.screwdriver",
            description: Text("firebase_setup_required_message")
        )
    }

    private var applicationShell: some View {
        TabView(
            selection: Binding(
                get: { router.selectedRoute },
                set: { router.select($0) }
            )
        ) {
            LearnHomeView(
                store: dependencies.curriculumStore,
                router: router
            )
            .tabItem { Label("Learn", systemImage: "book.fill") }
            .tag(AppRoute.learn)

            PracticeHomeView()
                .tabItem { Label("Practice", systemImage: "brain.head.profile") }
                .tag(AppRoute.practice)
            SocialHomeView()
                .tabItem { Label("Social", systemImage: "person.2.fill") }
                .tag(AppRoute.social)
            ProfileHomeView(
                coordinator: dependencies.onboardingCoordinator
            )
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(AppRoute.profile)
        }
    }
}
