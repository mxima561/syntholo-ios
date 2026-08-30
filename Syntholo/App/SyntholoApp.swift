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
    @State private var dependencies: AppDependencies
    private let rootPresentation: SyntholoRootPresentation

    init() {
        let configuration = FirebaseRuntimeConfiguration.current
        rootPresentation = SyntholoRootPresentation(
            isFirebaseConfigured: FirebaseBootstrap.configure(configuration)
        )
        _dependencies = State(
            initialValue: AppDependencies.make(
                configuration: configuration,
                isFirebaseConfigured: rootPresentation == .application,
                arguments: ProcessInfo.processInfo.arguments
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView(dependencies: dependencies)
            .onOpenURL { url in
                _ = GoogleSignInCoordinator.handle(url)
            }
        }
    }
}
