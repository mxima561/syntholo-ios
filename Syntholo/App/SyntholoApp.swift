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
            RootView(
                router: router,
                isFirebaseConfigured: rootPresentation == .application
            )
            .onOpenURL { url in
                _ = GoogleSignInCoordinator.handle(url)
            }
        }
    }
}
