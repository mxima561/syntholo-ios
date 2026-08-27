import SwiftUI

enum SyntholoRootPresentation: Equatable {
    case application
    case configurationRequired

    init(isFirebaseConfigured: Bool) {
        self = isFirebaseConfigured ? .application : .configurationRequired
    }
}

@main
struct SyntholoApp: App {
    @State private var router = AppRouter()
    private let rootPresentation: SyntholoRootPresentation

    init() {
        rootPresentation = SyntholoRootPresentation(
            isFirebaseConfigured: FirebaseBootstrap.configure(.current)
        )
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch rootPresentation {
                case .application:
                    RootView(router: router)
                case .configurationRequired:
                    ContentUnavailableView(
                        "firebase_setup_required_title",
                        systemImage: "wrench.and.screwdriver",
                        description: Text("firebase_setup_required_message")
                    )
                }
            }
            .onOpenURL { url in
                _ = GoogleSignInCoordinator.handle(url)
            }
        }
    }
}
