import SwiftUI

struct RootView: View {
    @Bindable var router: AppRouter
    @State private var onboardingStore = OnboardingStore(
        repository: .memory()
    )

    var body: some View {
        Group {
            if showsOnboardingFixture {
                OnboardingRootView(
                    store: onboardingStore,
                    onContinueWithApple: {},
                    onContinueWithGoogle: {},
                    onContinueWithEmail: {},
                    onStartFirstLesson: {}
                )
            } else {
                applicationShell
            }
        }
        .tint(SyntholoColor.accent)
    }

    private var showsOnboardingFixture: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("--ui-testing")
            && arguments.contains("--onboarding-reset")
    }

    private var applicationShell: some View {
        TabView(
            selection: Binding(
                get: { router.selectedRoute },
                set: { router.select($0) }
            )
        ) {
            LearnHomeView()
                .tabItem { Label("Learn", systemImage: "book.fill") }
                .tag(AppRoute.learn)
            PracticeHomeView()
                .tabItem { Label("Practice", systemImage: "brain.head.profile") }
                .tag(AppRoute.practice)
            SocialHomeView()
                .tabItem { Label("Social", systemImage: "person.2.fill") }
                .tag(AppRoute.social)
            ProfileHomeView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(AppRoute.profile)
        }
    }
}
