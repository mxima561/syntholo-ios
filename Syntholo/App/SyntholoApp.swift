import SwiftUI

@main
struct SyntholoApp: App {
    @State private var router = AppRouter()
    private let isFirebaseConfigured: Bool

    init() {
        isFirebaseConfigured = FirebaseBootstrap.configure(.current)
    }

    var body: some Scene {
        WindowGroup {
            if isFirebaseConfigured {
                RootView(router: router)
            } else {
                ContentUnavailableView(
                    "Setup required",
                    systemImage: "wrench.and.screwdriver",
                    description: Text(
                        "Firebase configuration is missing. See docs/setup/firebase.md."
                    )
                )
            }
        }
    }
}
