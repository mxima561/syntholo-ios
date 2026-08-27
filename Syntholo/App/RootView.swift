import SwiftUI

struct RootView: View {
    @Bindable var router: AppRouter

    var body: some View {
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
        .tint(SyntholoColor.accent)
    }
}
